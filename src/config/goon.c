#define _POSIX_C_SOURCE 200809L
#include "goon.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <libgen.h>

typedef enum {
    TOK_EOF,
    TOK_LBRACE,
    TOK_RBRACE,
    TOK_LBRACKET,
    TOK_RBRACKET,
    TOK_LPAREN,
    TOK_RPAREN,
    TOK_SEMICOLON,
    TOK_COMMA,
    TOK_EQUALS,
    TOK_COLON,
    TOK_QUESTION,
    TOK_SPREAD,
    TOK_DOTDOT,
    TOK_DOT,
    TOK_ARROW,
    TOK_INT,
    TOK_STRING,
    TOK_IDENT,
    TOK_TRUE,
    TOK_FALSE,
    TOK_LET,
    TOK_IF,
    TOK_THEN,
    TOK_ELSE,
    TOK_IMPORT,
} Token_Type;

typedef struct {
    Token_Type type;
    union {
        int64_t integer;
        char *string;
    } data;
} Token;

typedef struct {
    const char *src;
    size_t pos;
    size_t len;
    size_t line;
    size_t col;
    size_t line_start;
    size_t token_start;
    Token current;
    char *error;
    size_t error_line;
    size_t error_col;
} Lexer;

static void lexer_init(Lexer *lex, const char *src) {
    lex->src = src;
    lex->pos = 0;
    lex->len = strlen(src);
    lex->line = 1;
    lex->col = 1;
    lex->line_start = 0;
    lex->token_start = 0;
    lex->current.type = TOK_EOF;
    lex->current.data.string = NULL;
    lex->error = NULL;
    lex->error_line = 0;
    lex->error_col = 0;
}

static void lexer_set_error(Lexer *lex, const char *msg) {
    if (lex->error) free(lex->error);
    lex->error = strdup(msg);
    lex->error_line = lex->line;
    lex->error_col = lex->col;
}

typedef struct {
    size_t pos;
    size_t line;
    size_t col;
    size_t line_start;
    size_t token_start;
    Token current;
} Lexer_State;

static void lexer_save(Lexer *lex, Lexer_State *state) {
    state->pos = lex->pos;
    state->line = lex->line;
    state->col = lex->col;
    state->line_start = lex->line_start;
    state->token_start = lex->token_start;
    state->current = lex->current;
    if (lex->current.type == TOK_STRING || lex->current.type == TOK_IDENT) {
        state->current.data.string = strdup(lex->current.data.string);
    }
}

static void lexer_restore(Lexer *lex, Lexer_State *state) {
    if (lex->current.type == TOK_STRING || lex->current.type == TOK_IDENT) {
        free(lex->current.data.string);
    }
    lex->pos = state->pos;
    lex->line = state->line;
    lex->col = state->col;
    lex->line_start = state->line_start;
    lex->token_start = state->token_start;
    lex->current = state->current;
}

static void lexer_state_free(Lexer_State *state) {
    if (state->current.type == TOK_STRING || state->current.type == TOK_IDENT) {
        free(state->current.data.string);
        state->current.data.string = NULL;
    }
}

static void lexer_advance(Lexer *lex) {
    if (lex->pos < lex->len) {
        if (lex->src[lex->pos] == '\n') {
            lex->line++;
            lex->col = 1;
            lex->pos++;
            lex->line_start = lex->pos;
        } else {
            lex->col++;
            lex->pos++;
        }
    }
}

static void lexer_skip_whitespace(Lexer *lex) {
    while (lex->pos < lex->len) {
        char c = lex->src[lex->pos];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
            lexer_advance(lex);
        } else if (c == '/' && lex->pos + 1 < lex->len && lex->src[lex->pos + 1] == '/') {
            lexer_advance(lex);
            lexer_advance(lex);
            while (lex->pos < lex->len && lex->src[lex->pos] != '\n') {
                lexer_advance(lex);
            }
        } else if (c == '/' && lex->pos + 1 < lex->len && lex->src[lex->pos + 1] == '*') {
            lexer_advance(lex);
            lexer_advance(lex);
            while (lex->pos + 1 < lex->len) {
                if (lex->src[lex->pos] == '*' && lex->src[lex->pos + 1] == '/') {
                    lexer_advance(lex);
                    lexer_advance(lex);
                    break;
                }
                lexer_advance(lex);
            }
        } else {
            break;
        }
    }
}

static bool is_ident_start(char c) {
    return isalpha(c) || c == '_';
}

static bool is_ident_char(char c) {
    return isalnum(c) || c == '_';
}

static char *strdup_range(const char *start, size_t len) {
    char *s = malloc(len + 1);
    if (!s) return NULL;
    memcpy(s, start, len);
    s[len] = '\0';
    return s;
}

static bool lexer_next(Lexer *lex) {
    if (lex->current.type == TOK_STRING || lex->current.type == TOK_IDENT) {
        free(lex->current.data.string);
        lex->current.data.string = NULL;
    }

    lexer_skip_whitespace(lex);
    lex->token_start = lex->pos;

    if (lex->pos >= lex->len) {
        lex->current.type = TOK_EOF;
        return true;
    }

    char c = lex->src[lex->pos];

    if (c == '{') { lex->current.type = TOK_LBRACE; lexer_advance(lex); return true; }
    if (c == '}') { lex->current.type = TOK_RBRACE; lexer_advance(lex); return true; }
    if (c == '[') { lex->current.type = TOK_LBRACKET; lexer_advance(lex); return true; }
    if (c == ']') { lex->current.type = TOK_RBRACKET; lexer_advance(lex); return true; }
    if (c == '(') { lex->current.type = TOK_LPAREN; lexer_advance(lex); return true; }
    if (c == ')') { lex->current.type = TOK_RPAREN; lexer_advance(lex); return true; }
    if (c == ';') { lex->current.type = TOK_SEMICOLON; lexer_advance(lex); return true; }
    if (c == ',') { lex->current.type = TOK_COMMA; lexer_advance(lex); return true; }
    if (c == '=' && lex->pos + 1 < lex->len && lex->src[lex->pos + 1] == '>') {
        lex->current.type = TOK_ARROW;
        lexer_advance(lex);
        lexer_advance(lex);
        return true;
    }
    if (c == '=') { lex->current.type = TOK_EQUALS; lexer_advance(lex); return true; }
    if (c == ':') { lex->current.type = TOK_COLON; lexer_advance(lex); return true; }
    if (c == '?') { lex->current.type = TOK_QUESTION; lexer_advance(lex); return true; }

    if (c == '.' && lex->pos + 2 < lex->len &&
        lex->src[lex->pos + 1] == '.' && lex->src[lex->pos + 2] == '.') {
        lex->current.type = TOK_SPREAD;
        lexer_advance(lex);
        lexer_advance(lex);
        lexer_advance(lex);
        return true;
    }

    if (c == '.' && lex->pos + 1 < lex->len && lex->src[lex->pos + 1] == '.') {
        lex->current.type = TOK_DOTDOT;
        lexer_advance(lex);
        lexer_advance(lex);
        return true;
    }

    if (c == '.') {
        lex->current.type = TOK_DOT;
        lexer_advance(lex);
        return true;
    }

    if (c == '"') {
        lexer_advance(lex);
        size_t buf_size = 256;
        size_t buf_len = 0;
        char *buf = malloc(buf_size);
        if (!buf) return false;

        while (lex->pos < lex->len && lex->src[lex->pos] != '"') {
            char ch = lex->src[lex->pos];
            if (ch == '\\' && lex->pos + 1 < lex->len) {
                lexer_advance(lex);
                ch = lex->src[lex->pos];
                switch (ch) {
                    case 'n': ch = '\n'; break;
                    case 't': ch = '\t'; break;
                    case 'r': ch = '\r'; break;
                    case '\\': ch = '\\'; break;
                    case '"': ch = '"'; break;
                    case '$': ch = '$'; break;
                    default: break;
                }
            }
            if (buf_len + 1 >= buf_size) {
                buf_size *= 2;
                buf = realloc(buf, buf_size);
                if (!buf) return false;
            }
            buf[buf_len++] = ch;
            lexer_advance(lex);
        }

        if (lex->pos >= lex->len) {
            free(buf);
            lexer_set_error(lex, "unterminated string");
            return false;
        }

        lexer_advance(lex);
        buf[buf_len] = '\0';
        lex->current.type = TOK_STRING;
        lex->current.data.string = buf;
        return true;
    }

    if (isdigit(c) || (c == '-' && lex->pos + 1 < lex->len && isdigit(lex->src[lex->pos + 1]))) {
        int sign = 1;
        if (c == '-') {
            sign = -1;
            lexer_advance(lex);
        }
        int64_t val = 0;
        while (lex->pos < lex->len && isdigit(lex->src[lex->pos])) {
            val = val * 10 + (lex->src[lex->pos] - '0');
            lexer_advance(lex);
        }
        lex->current.type = TOK_INT;
        lex->current.data.integer = val * sign;
        return true;
    }

    if (is_ident_start(c)) {
        size_t start = lex->pos;
        while (lex->pos < lex->len && is_ident_char(lex->src[lex->pos])) {
            lexer_advance(lex);
        }
        char *ident = strdup_range(lex->src + start, lex->pos - start);

        if (strcmp(ident, "true") == 0) {
            free(ident);
            lex->current.type = TOK_TRUE;
            return true;
        }
        if (strcmp(ident, "false") == 0) {
            free(ident);
            lex->current.type = TOK_FALSE;
            return true;
        }
        if (strcmp(ident, "let") == 0) {
            free(ident);
            lex->current.type = TOK_LET;
            return true;
        }
        if (strcmp(ident, "if") == 0) {
            free(ident);
            lex->current.type = TOK_IF;
            return true;
        }
        if (strcmp(ident, "then") == 0) {
            free(ident);
            lex->current.type = TOK_THEN;
            return true;
        }
        if (strcmp(ident, "else") == 0) {
            free(ident);
            lex->current.type = TOK_ELSE;
            return true;
        }
        if (strcmp(ident, "import") == 0) {
            free(ident);
            lex->current.type = TOK_IMPORT;
            return true;
        }

        lex->current.type = TOK_IDENT;
        lex->current.data.string = ident;
        return true;
    }

    lexer_set_error(lex, "unexpected character");
    return false;
}

static Goon_Value *alloc_value(Goon_Ctx *ctx) {
    Goon_Value *val = malloc(sizeof(Goon_Value));
    if (!val) return NULL;
    val->type = GOON_NIL;
    val->next_alloc = ctx->values;
    ctx->values = val;
    return val;
}

static Goon_Record_Field *alloc_field(Goon_Ctx *ctx) {
    Goon_Record_Field *field = malloc(sizeof(Goon_Record_Field));
    if (!field) return NULL;
    field->key = NULL;
    field->value = NULL;
    field->next = ctx->fields;
    ctx->fields = field;
    return field;
}

Goon_Value *goon_nil(Goon_Ctx *ctx) {
    Goon_Value *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOON_NIL;
    return val;
}

Goon_Value *goon_bool(Goon_Ctx *ctx, bool b) {
    Goon_Value *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOON_BOOL;
    val->data.boolean = b;
    return val;
}

Goon_Value *goon_int(Goon_Ctx *ctx, int64_t i) {
    Goon_Value *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOON_INT;
    val->data.integer = i;
    return val;
}

Goon_Value *goon_string(Goon_Ctx *ctx, const char *s) {
    Goon_Value *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOON_STRING;
    val->data.string = strdup(s);
    return val;
}

Goon_Value *goon_list(Goon_Ctx *ctx) {
    Goon_Value *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOON_LIST;
    val->data.list.items = NULL;
    val->data.list.len = 0;
    val->data.list.cap = 0;
    return val;
}

Goon_Value *goon_record(Goon_Ctx *ctx) {
    Goon_Value *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOON_RECORD;
    val->data.record.fields = NULL;
    return val;
}

static Goon_Value *goon_lambda(Goon_Ctx *ctx, char **params, size_t param_count, const char *body, Goon_Binding *env) {
    Goon_Value *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOON_LAMBDA;
    val->data.lambda.params = malloc(param_count * sizeof(char *));
    if (!val->data.lambda.params && param_count > 0) return NULL;
    for (size_t i = 0; i < param_count; i++) {
        val->data.lambda.params[i] = strdup(params[i]);
    }
    val->data.lambda.param_count = param_count;
    val->data.lambda.body = strdup(body);
    val->data.lambda.env = env;
    return val;
}

bool goon_is_nil(Goon_Value *val) {
    return val == NULL || val->type == GOON_NIL;
}

bool goon_is_bool(Goon_Value *val) {
    return val != NULL && val->type == GOON_BOOL;
}

bool goon_is_int(Goon_Value *val) {
    return val != NULL && val->type == GOON_INT;
}

bool goon_is_string(Goon_Value *val) {
    return val != NULL && val->type == GOON_STRING;
}

bool goon_is_list(Goon_Value *val) {
    return val != NULL && val->type == GOON_LIST;
}

bool goon_is_record(Goon_Value *val) {
    return val != NULL && val->type == GOON_RECORD;
}

bool goon_to_bool(Goon_Value *val) {
    if (val == NULL) return false;
    if (val->type == GOON_BOOL) return val->data.boolean;
    if (val->type == GOON_NIL) return false;
    return true;
}

int64_t goon_to_int(Goon_Value *val) {
    if (val == NULL || val->type != GOON_INT) return 0;
    return val->data.integer;
}

const char *goon_to_string(Goon_Value *val) {
    if (val == NULL || val->type != GOON_STRING) return NULL;
    return val->data.string;
}

void goon_list_push(Goon_Ctx *ctx, Goon_Value *list, Goon_Value *item) {
    (void)ctx;
    if (!list || list->type != GOON_LIST) return;
    if (list->data.list.len >= list->data.list.cap) {
        size_t new_cap = list->data.list.cap == 0 ? 8 : list->data.list.cap * 2;
        Goon_Value **new_items = realloc(list->data.list.items, new_cap * sizeof(Goon_Value *));
        if (!new_items) return;
        list->data.list.items = new_items;
        list->data.list.cap = new_cap;
    }
    list->data.list.items[list->data.list.len++] = item;
}

size_t goon_list_len(Goon_Value *list) {
    if (!list || list->type != GOON_LIST) return 0;
    return list->data.list.len;
}

Goon_Value *goon_list_get(Goon_Value *list, size_t index) {
    if (!list || list->type != GOON_LIST) return NULL;
    if (index >= list->data.list.len) return NULL;
    return list->data.list.items[index];
}

void goon_record_set(Goon_Ctx *ctx, Goon_Value *record, const char *key, Goon_Value *value) {
    if (!record || record->type != GOON_RECORD) return;

    Goon_Record_Field *f = record->data.record.fields;
    while (f) {
        if (strcmp(f->key, key) == 0) {
            f->value = value;
            return;
        }
        f = f->next;
    }

    Goon_Record_Field *field = alloc_field(ctx);
    if (!field) return;
    field->key = strdup(key);
    field->value = value;
    field->next = record->data.record.fields;
    record->data.record.fields = field;
}

Goon_Value *goon_record_get(Goon_Value *record, const char *key) {
    if (!record || record->type != GOON_RECORD) return NULL;
    Goon_Record_Field *f = record->data.record.fields;
    while (f) {
        if (strcmp(f->key, key) == 0) {
            return f->value;
        }
        f = f->next;
    }
    return NULL;
}

Goon_Record_Field *goon_record_fields(Goon_Value *record) {
    if (!record || record->type != GOON_RECORD) return NULL;
    return record->data.record.fields;
}

static Goon_Value *lookup(Goon_Ctx *ctx, const char *name) {
    Goon_Binding *b = ctx->env;
    while (b) {
        if (strcmp(b->name, name) == 0) {
            return b->value;
        }
        b = b->next;
    }
    return NULL;
}

static void define(Goon_Ctx *ctx, const char *name, Goon_Value *value) {
    Goon_Binding *b = ctx->env;
    while (b) {
        if (strcmp(b->name, name) == 0) {
            b->value = value;
            return;
        }
        b = b->next;
    }
    b = malloc(sizeof(Goon_Binding));
    if (!b) return;
    b->name = strdup(name);
    b->value = value;
    b->next = ctx->env;
    ctx->env = b;
}

typedef struct {
    Goon_Ctx *ctx;
    Lexer *lex;
} Parser;

static Goon_Value *parse_expr(Parser *p);

static Goon_Value *call_lambda(Goon_Ctx *ctx, Goon_Value *fn, Goon_Value **args, size_t argc) {
    if (!fn || fn->type != GOON_LAMBDA) return goon_nil(ctx);
    if (argc != fn->data.lambda.param_count) return goon_nil(ctx);

    Goon_Binding *old_env = ctx->env;
    ctx->env = fn->data.lambda.env;

    for (size_t i = 0; i < argc; i++) {
        define(ctx, fn->data.lambda.params[i], args[i]);
    }

    Lexer body_lex;
    lexer_init(&body_lex, fn->data.lambda.body);
    Parser body_parser;
    body_parser.ctx = ctx;
    body_parser.lex = &body_lex;

    if (!lexer_next(&body_lex)) {
        ctx->env = old_env;
        return goon_nil(ctx);
    }

    Goon_Value *result = parse_expr(&body_parser);

    ctx->env = old_env;
    return result ? result : goon_nil(ctx);
}

static Goon_Value *builtin_map(Goon_Ctx *ctx, Goon_Value **args, size_t argc) {
    if (argc != 2) return goon_nil(ctx);
    Goon_Value *list = args[0];
    Goon_Value *fn = args[1];

    if (!list || list->type != GOON_LIST) return goon_nil(ctx);
    if (!fn || (fn->type != GOON_LAMBDA && fn->type != GOON_BUILTIN)) return goon_nil(ctx);

    Goon_Value *result = goon_list(ctx);

    for (size_t i = 0; i < list->data.list.len; i++) {
        Goon_Value *item = list->data.list.items[i];
        Goon_Value *mapped;

        if (fn->type == GOON_LAMBDA) {
            Goon_Value *fn_args[1] = { item };
            mapped = call_lambda(ctx, fn, fn_args, 1);
        } else {
            Goon_Value *fn_args[1] = { item };
            mapped = fn->data.builtin(ctx, fn_args, 1);
        }

        goon_list_push(ctx, result, mapped);
    }

    return result;
}

static Goon_Value *interpolate_string(Goon_Ctx *ctx, const char *str) {
    size_t len = strlen(str);
    size_t buf_size = len * 2 + 1;
    char *buf = malloc(buf_size);
    if (!buf) return goon_string(ctx, str);

    size_t buf_len = 0;
    size_t i = 0;

    while (i < len) {
        if (str[i] == '$' && i + 1 < len && str[i + 1] == '{') {
            i += 2;
            size_t var_start = i;
            while (i < len && str[i] != '}') {
                i++;
            }
            if (i < len) {
                char *var_name = strdup_range(str + var_start, i - var_start);
                Goon_Value *val = lookup(ctx, var_name);
                free(var_name);

                if (val) {
                    const char *insert = NULL;
                    char num_buf[32];
                    if (val->type == GOON_STRING) {
                        insert = val->data.string;
                    } else if (val->type == GOON_INT) {
                        snprintf(num_buf, sizeof(num_buf), "%ld", val->data.integer);
                        insert = num_buf;
                    } else if (val->type == GOON_BOOL) {
                        insert = val->data.boolean ? "true" : "false";
                    }
                    if (insert) {
                        size_t insert_len = strlen(insert);
                        while (buf_len + insert_len >= buf_size) {
                            buf_size *= 2;
                            buf = realloc(buf, buf_size);
                        }
                        memcpy(buf + buf_len, insert, insert_len);
                        buf_len += insert_len;
                    }
                }
                i++;
            }
        } else {
            if (buf_len + 1 >= buf_size) {
                buf_size *= 2;
                buf = realloc(buf, buf_size);
            }
            buf[buf_len++] = str[i++];
        }
    }

    buf[buf_len] = '\0';
    Goon_Value *result = goon_string(ctx, buf);
    free(buf);
    return result;
}

static Goon_Value *parse_record(Parser *p) {
    Goon_Value *record = goon_record(p->ctx);

    if (!lexer_next(p->lex)) return NULL;

    while (p->lex->current.type != TOK_RBRACE && p->lex->current.type != TOK_EOF) {
        if (p->lex->current.type == TOK_SPREAD) {
            if (!lexer_next(p->lex)) return NULL;
            Goon_Value *spread_val = parse_expr(p);
            if (spread_val && spread_val->type == GOON_RECORD) {
                Goon_Record_Field *f = spread_val->data.record.fields;
                while (f) {
                    goon_record_set(p->ctx, record, f->key, f->value);
                    f = f->next;
                }
            }
            if (p->lex->current.type == TOK_COMMA) {
                if (!lexer_next(p->lex)) return NULL;
            } else if (p->lex->current.type == TOK_SEMICOLON) {
                if (!lexer_next(p->lex)) return NULL;
            }
            continue;
        }

        if (p->lex->current.type != TOK_IDENT) {
            lexer_set_error(p->lex, "expected field name");
            return NULL;
        }

        char *key = strdup(p->lex->current.data.string);
        if (!lexer_next(p->lex)) { free(key); return NULL; }

        if (p->lex->current.type == TOK_COLON) {
            if (!lexer_next(p->lex)) { free(key); return NULL; }
            if (!lexer_next(p->lex)) { free(key); return NULL; }
        }

        if (p->lex->current.type != TOK_EQUALS) {
            lexer_set_error(p->lex, "expected = after field name");
            free(key);
            return NULL;
        }

        if (!lexer_next(p->lex)) { free(key); return NULL; }

        Goon_Value *value = parse_expr(p);
        if (!value) { free(key); return NULL; }

        goon_record_set(p->ctx, record, key, value);
        free(key);

        if (p->lex->current.type == TOK_SEMICOLON) {
            if (!lexer_next(p->lex)) return NULL;
        } else if (p->lex->current.type == TOK_COMMA) {
            if (!lexer_next(p->lex)) return NULL;
        }
    }

    if (p->lex->current.type != TOK_RBRACE) {
        lexer_set_error(p->lex, "expected }");
        return NULL;
    }

    if (!lexer_next(p->lex)) return NULL;
    return record;
}

static Goon_Value *parse_list(Parser *p) {
    Goon_Value *list = goon_list(p->ctx);

    if (!lexer_next(p->lex)) return NULL;

    while (p->lex->current.type != TOK_RBRACKET && p->lex->current.type != TOK_EOF) {
        if (p->lex->current.type == TOK_SPREAD) {
            if (!lexer_next(p->lex)) return NULL;
            Goon_Value *spread_val = parse_expr(p);
            if (spread_val && spread_val->type == GOON_LIST) {
                for (size_t i = 0; i < spread_val->data.list.len; i++) {
                    goon_list_push(p->ctx, list, spread_val->data.list.items[i]);
                }
            }
        } else if (p->lex->current.type == TOK_INT) {
            int64_t start = p->lex->current.data.integer;
            if (!lexer_next(p->lex)) return NULL;

            if (p->lex->current.type == TOK_DOTDOT) {
                if (!lexer_next(p->lex)) return NULL;
                if (p->lex->current.type != TOK_INT) {
                    lexer_set_error(p->lex, "expected integer after ..");
                    return NULL;
                }
                int64_t end = p->lex->current.data.integer;
                if (!lexer_next(p->lex)) return NULL;

                for (int64_t i = start; i <= end; i++) {
                    goon_list_push(p->ctx, list, goon_int(p->ctx, i));
                }
            } else {
                goon_list_push(p->ctx, list, goon_int(p->ctx, start));
            }
        } else {
            Goon_Value *item = parse_expr(p);
            if (!item) return NULL;
            goon_list_push(p->ctx, list, item);
        }

        if (p->lex->current.type == TOK_COMMA) {
            if (!lexer_next(p->lex)) return NULL;
        }
    }

    if (p->lex->current.type != TOK_RBRACKET) {
        lexer_set_error(p->lex, "expected ]");
        return NULL;
    }

    if (!lexer_next(p->lex)) return NULL;
    return list;
}

static Goon_Value *parse_import(Parser *p) {
    if (!lexer_next(p->lex)) return NULL;

    if (p->lex->current.type != TOK_LPAREN) {
        lexer_set_error(p->lex,"expected ( after import");
        return NULL;
    }

    if (!lexer_next(p->lex)) return NULL;

    if (p->lex->current.type != TOK_STRING) {
        lexer_set_error(p->lex,"expected string path in import");
        return NULL;
    }

    char *path = strdup(p->lex->current.data.string);
    if (!lexer_next(p->lex)) { free(path); return NULL; }

    if (p->lex->current.type != TOK_RPAREN) {
        lexer_set_error(p->lex,"expected ) after import path");
        free(path);
        return NULL;
    }

    if (!lexer_next(p->lex)) { free(path); return NULL; }

    char full_path[1024];
    if (path[0] == '.' && p->ctx->base_path) {
        char *base_copy = strdup(p->ctx->base_path);
        char *dir = dirname(base_copy);
        snprintf(full_path, sizeof(full_path), "%s/%s", dir, path);
        free(base_copy);
    } else if (p->ctx->base_path && path[0] != '/') {
        char *base_copy = strdup(p->ctx->base_path);
        char *dir = dirname(base_copy);
        snprintf(full_path, sizeof(full_path), "%s/%s", dir, path);
        free(base_copy);
    } else {
        snprintf(full_path, sizeof(full_path), "%s", path);
    }

    size_t plen = strlen(full_path);
    if (plen < 5 || strcmp(full_path + plen - 5, ".goon") != 0) {
        strncat(full_path, ".goon", sizeof(full_path) - plen - 1);
    }

    free(path);

    FILE *f = fopen(full_path, "r");
    if (!f) {
        lexer_set_error(p->lex,"could not open import file");
        return NULL;
    }

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);

    char *source = malloc(size + 1);
    if (!source) {
        fclose(f);
        return NULL;
    }

    size_t read_size = fread(source, 1, size, f);
    source[read_size] = '\0';
    fclose(f);

    char *old_base = p->ctx->base_path;
    p->ctx->base_path = strdup(full_path);

    Lexer import_lex;
    lexer_init(&import_lex, source);
    Parser import_parser;
    import_parser.ctx = p->ctx;
    import_parser.lex = &import_lex;

    if (!lexer_next(&import_lex)) {
        free(source);
        free(p->ctx->base_path);
        p->ctx->base_path = old_base;
        return NULL;
    }

    Goon_Value *result = NULL;
    while (import_lex.current.type != TOK_EOF) {
        result = parse_expr(&import_parser);
        if (!result) break;
    }

    free(source);
    free(p->ctx->base_path);
    p->ctx->base_path = old_base;

    return result;
}

static Goon_Value *parse_call(Parser *p, const char *name) {
    Goon_Value *fn = lookup(p->ctx, name);

    if (!lexer_next(p->lex)) return NULL;

    Goon_Value *args[16];
    size_t argc = 0;

    while (p->lex->current.type != TOK_RPAREN && p->lex->current.type != TOK_EOF && argc < 16) {
        args[argc++] = parse_expr(p);
        if (p->lex->current.type == TOK_COMMA) {
            if (!lexer_next(p->lex)) return NULL;
        }
    }

    if (p->lex->current.type != TOK_RPAREN) {
        lexer_set_error(p->lex,"expected )");
        return NULL;
    }

    if (!lexer_next(p->lex)) return NULL;

    if (fn && fn->type == GOON_BUILTIN) {
        return fn->data.builtin(p->ctx, args, argc);
    }

    if (fn && fn->type == GOON_LAMBDA) {
        if (argc != fn->data.lambda.param_count) {
            lexer_set_error(p->lex, "wrong number of arguments");
            return NULL;
        }

        Goon_Binding *old_env = p->ctx->env;
        p->ctx->env = fn->data.lambda.env;

        for (size_t i = 0; i < argc; i++) {
            define(p->ctx, fn->data.lambda.params[i], args[i]);
        }

        Lexer body_lex;
        lexer_init(&body_lex, fn->data.lambda.body);
        Parser body_parser;
        body_parser.ctx = p->ctx;
        body_parser.lex = &body_lex;

        if (!lexer_next(&body_lex)) {
            p->ctx->env = old_env;
            return NULL;
        }

        Goon_Value *result = parse_expr(&body_parser);

        p->ctx->env = old_env;
        return result ? result : goon_nil(p->ctx);
    }

    return goon_nil(p->ctx);
}

static Goon_Value *parse_primary(Parser *p) {
    Token tok = p->lex->current;

    switch (tok.type) {
        case TOK_INT: {
            Goon_Value *val = goon_int(p->ctx, tok.data.integer);
            if (!lexer_next(p->lex)) return NULL;
            return val;
        }

        case TOK_STRING: {
            Goon_Value *val = interpolate_string(p->ctx, tok.data.string);
            if (!lexer_next(p->lex)) return NULL;
            return val;
        }

        case TOK_TRUE: {
            Goon_Value *val = goon_bool(p->ctx, true);
            if (!lexer_next(p->lex)) return NULL;
            return val;
        }

        case TOK_FALSE: {
            Goon_Value *val = goon_bool(p->ctx, false);
            if (!lexer_next(p->lex)) return NULL;
            return val;
        }

        case TOK_IDENT: {
            char *name = strdup(tok.data.string);
            if (!lexer_next(p->lex)) { free(name); return NULL; }

            if (p->lex->current.type == TOK_LPAREN) {
                Goon_Value *result = parse_call(p, name);
                free(name);
                return result;
            }

            if (p->lex->current.type == TOK_DOT) {
                Goon_Value *val = lookup(p->ctx, name);
                free(name);

                while (p->lex->current.type == TOK_DOT) {
                    if (!lexer_next(p->lex)) return NULL;
                    if (p->lex->current.type != TOK_IDENT) {
                        lexer_set_error(p->lex,"expected field name after .");
                        return NULL;
                    }
                    char *field = p->lex->current.data.string;
                    val = goon_record_get(val, field);
                    if (!lexer_next(p->lex)) return NULL;
                }
                return val ? val : goon_nil(p->ctx);
            }

            Goon_Value *val = lookup(p->ctx, name);
            free(name);
            return val ? val : goon_nil(p->ctx);
        }

        case TOK_LBRACE:
            return parse_record(p);

        case TOK_LBRACKET:
            return parse_list(p);

        case TOK_IMPORT:
            return parse_import(p);

        case TOK_LPAREN: {
            Lexer_State saved;
            lexer_save(p->lex, &saved);

            if (!lexer_next(p->lex)) { lexer_state_free(&saved); return NULL; }

            char *params[16];
            size_t param_count = 0;
            bool is_lambda = true;

            if (p->lex->current.type == TOK_RPAREN) {
                if (!lexer_next(p->lex)) { lexer_state_free(&saved); return NULL; }
                is_lambda = (p->lex->current.type == TOK_ARROW);
            } else if (p->lex->current.type == TOK_IDENT) {
                while (is_lambda && param_count < 16) {
                    if (p->lex->current.type != TOK_IDENT) {
                        is_lambda = false;
                        break;
                    }
                    params[param_count++] = strdup(p->lex->current.data.string);
                    if (!lexer_next(p->lex)) {
                        for (size_t i = 0; i < param_count; i++) free(params[i]);
                        lexer_state_free(&saved);
                        return NULL;
                    }
                    if (p->lex->current.type == TOK_COMMA) {
                        if (!lexer_next(p->lex)) {
                            for (size_t i = 0; i < param_count; i++) free(params[i]);
                            lexer_state_free(&saved);
                            return NULL;
                        }
                    } else if (p->lex->current.type == TOK_RPAREN) {
                        if (!lexer_next(p->lex)) {
                            for (size_t i = 0; i < param_count; i++) free(params[i]);
                            lexer_state_free(&saved);
                            return NULL;
                        }
                        is_lambda = (p->lex->current.type == TOK_ARROW);
                        break;
                    } else {
                        is_lambda = false;
                        break;
                    }
                }
            } else {
                is_lambda = false;
            }

            if (is_lambda) {
                lexer_state_free(&saved);
                if (!lexer_next(p->lex)) {
                    for (size_t i = 0; i < param_count; i++) free(params[i]);
                    return NULL;
                }
                size_t body_start = p->lex->token_start;
                Goon_Value *body_val = parse_expr(p);
                if (!body_val) {
                    for (size_t i = 0; i < param_count; i++) free(params[i]);
                    return NULL;
                }
                size_t body_end = p->lex->token_start;
                char *body_src = strdup_range(p->lex->src + body_start, body_end - body_start);

                Goon_Value *lambda = goon_lambda(p->ctx, params, param_count, body_src, p->ctx->env);
                free(body_src);
                for (size_t i = 0; i < param_count; i++) free(params[i]);
                return lambda;
            } else {
                for (size_t i = 0; i < param_count; i++) free(params[i]);
                lexer_restore(p->lex, &saved);

                if (!lexer_next(p->lex)) return NULL;
                Goon_Value *val = parse_expr(p);
                if (p->lex->current.type != TOK_RPAREN) {
                    lexer_set_error(p->lex, "expected )");
                    return NULL;
                }
                if (!lexer_next(p->lex)) return NULL;
                return val;
            }
        }

        default:
            return NULL;
    }
}

static Goon_Value *parse_expr(Parser *p) {
    if (p->lex->current.type == TOK_LET) {
        if (!lexer_next(p->lex)) return NULL;

        if (p->lex->current.type != TOK_IDENT) {
            lexer_set_error(p->lex,"expected identifier after let");
            return NULL;
        }

        char *name = strdup(p->lex->current.data.string);
        if (!lexer_next(p->lex)) { free(name); return NULL; }

        if (p->lex->current.type == TOK_COLON) {
            if (!lexer_next(p->lex)) { free(name); return NULL; }
            if (!lexer_next(p->lex)) { free(name); return NULL; }
        }

        if (p->lex->current.type != TOK_EQUALS) {
            lexer_set_error(p->lex,"expected = in let binding");
            free(name);
            return NULL;
        }

        if (!lexer_next(p->lex)) { free(name); return NULL; }

        Goon_Value *value = parse_expr(p);
        if (!value) { free(name); return NULL; }

        define(p->ctx, name, value);
        free(name);

        if (p->lex->current.type != TOK_SEMICOLON) {
            lexer_set_error(p->lex, "expected ; after let binding");
            return NULL;
        }
        if (!lexer_next(p->lex)) return NULL;

        return value;
    }

    if (p->lex->current.type == TOK_IF) {
        if (!lexer_next(p->lex)) return NULL;

        Goon_Value *cond = parse_expr(p);
        if (!cond) return NULL;

        if (p->lex->current.type != TOK_THEN) {
            lexer_set_error(p->lex,"expected 'then' after if condition");
            return NULL;
        }

        if (!lexer_next(p->lex)) return NULL;

        Goon_Value *then_val = parse_expr(p);
        if (!then_val) return NULL;

        if (p->lex->current.type != TOK_ELSE) {
            lexer_set_error(p->lex,"expected 'else' after then branch");
            return NULL;
        }

        if (!lexer_next(p->lex)) return NULL;

        Goon_Value *else_val = parse_expr(p);
        if (!else_val) return NULL;

        return goon_to_bool(cond) ? then_val : else_val;
    }

    Goon_Value *val = parse_primary(p);
    if (!val) return NULL;

    if (p->lex->current.type == TOK_QUESTION) {
        if (!lexer_next(p->lex)) return NULL;

        Goon_Value *then_val = parse_expr(p);
        if (!then_val) return NULL;

        if (p->lex->current.type != TOK_COLON) {
            lexer_set_error(p->lex,"expected : in ternary");
            return NULL;
        }

        if (!lexer_next(p->lex)) return NULL;

        Goon_Value *else_val = parse_expr(p);
        if (!else_val) return NULL;

        return goon_to_bool(val) ? then_val : else_val;
    }

    return val;
}

static void clear_error(Goon_Ctx *ctx) {
    if (ctx->error.message) { free(ctx->error.message); ctx->error.message = NULL; }
    if (ctx->error.file) { free(ctx->error.file); ctx->error.file = NULL; }
    if (ctx->error.source_line) { free(ctx->error.source_line); ctx->error.source_line = NULL; }
    ctx->error.line = 0;
    ctx->error.col = 0;
}

static char *get_source_line(const char *src, size_t line_start) {
    const char *start = src + line_start;
    const char *end = start;
    while (*end && *end != '\n') end++;
    return strdup_range(start, end - start);
}

Goon_Ctx *goon_create(void) {
    Goon_Ctx *ctx = malloc(sizeof(Goon_Ctx));
    if (!ctx) return NULL;
    ctx->env = NULL;
    ctx->values = NULL;
    ctx->fields = NULL;
    ctx->error.message = NULL;
    ctx->error.file = NULL;
    ctx->error.line = 0;
    ctx->error.col = 0;
    ctx->error.source_line = NULL;
    ctx->base_path = NULL;
    ctx->userdata = NULL;

    goon_register(ctx, "map", builtin_map);

    return ctx;
}

void goon_destroy(Goon_Ctx *ctx) {
    if (!ctx) return;

    Goon_Binding *b = ctx->env;
    while (b) {
        Goon_Binding *next = b->next;
        free(b->name);
        free(b);
        b = next;
    }

    Goon_Value *v = ctx->values;
    while (v) {
        Goon_Value *next = v->next_alloc;
        if (v->type == GOON_STRING && v->data.string) {
            free(v->data.string);
        } else if (v->type == GOON_LIST && v->data.list.items) {
            free(v->data.list.items);
        } else if (v->type == GOON_LAMBDA) {
            if (v->data.lambda.params) {
                for (size_t i = 0; i < v->data.lambda.param_count; i++) {
                    free(v->data.lambda.params[i]);
                }
                free(v->data.lambda.params);
            }
            if (v->data.lambda.body) {
                free(v->data.lambda.body);
            }
        }
        free(v);
        v = next;
    }

    Goon_Record_Field *f = ctx->fields;
    while (f) {
        Goon_Record_Field *next = f->next;
        if (f->key) free(f->key);
        free(f);
        f = next;
    }

    clear_error(ctx);
    if (ctx->base_path) free(ctx->base_path);
    free(ctx);
}

void goon_set_userdata(Goon_Ctx *ctx, void *userdata) {
    ctx->userdata = userdata;
}

void *goon_get_userdata(Goon_Ctx *ctx) {
    return ctx->userdata;
}

void goon_register(Goon_Ctx *ctx, const char *name, Goon_Builtin_Fn fn) {
    Goon_Value *val = alloc_value(ctx);
    if (!val) return;
    val->type = GOON_BUILTIN;
    val->data.builtin = fn;
    define(ctx, name, val);
}

static Goon_Value *last_result = NULL;

static void set_error_from_lexer(Goon_Ctx *ctx, Lexer *lex, const char *source) {
    clear_error(ctx);
    if (lex->error) {
        ctx->error.message = lex->error;
        lex->error = NULL;
    }
    ctx->error.line = lex->error_line > 0 ? lex->error_line : lex->line;
    ctx->error.col = lex->error_col > 0 ? lex->error_col : lex->col;
    if (ctx->base_path) {
        ctx->error.file = strdup(ctx->base_path);
    }
    size_t line_start = lex->line_start;
    if (lex->error_line > 0 && lex->error_line < lex->line) {
        const char *p = source;
        size_t cur_line = 1;
        while (*p && cur_line < lex->error_line) {
            if (*p == '\n') cur_line++;
            p++;
        }
        line_start = p - source;
    }
    ctx->error.source_line = get_source_line(source, line_start);
}

bool goon_load_string(Goon_Ctx *ctx, const char *source) {
    Lexer lex;
    lexer_init(&lex, source);

    Parser parser;
    parser.ctx = ctx;
    parser.lex = &lex;

    if (!lexer_next(&lex)) {
        set_error_from_lexer(ctx, &lex, source);
        return false;
    }

    last_result = NULL;

    while (lex.current.type != TOK_EOF) {
        Goon_Value *expr = parse_expr(&parser);
        if (!expr) {
            set_error_from_lexer(ctx, &lex, source);
            return false;
        }
        last_result = expr;
    }

    return true;
}

bool goon_load_file(Goon_Ctx *ctx, const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) {
        clear_error(ctx);
        ctx->error.message = strdup("could not open file");
        ctx->error.file = strdup(path);
        return false;
    }

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);

    char *source = malloc(size + 1);
    if (!source) {
        fclose(f);
        clear_error(ctx);
        ctx->error.message = strdup("out of memory");
        return false;
    }

    size_t read_size = fread(source, 1, size, f);
    source[read_size] = '\0';
    fclose(f);

    ctx->base_path = strdup(path);

    bool result = goon_load_string(ctx, source);
    free(source);
    return result;
}

const char *goon_get_error(Goon_Ctx *ctx) {
    return ctx->error.message;
}

const Goon_Error *goon_get_error_info(Goon_Ctx *ctx) {
    if (!ctx->error.message) return NULL;
    return &ctx->error;
}

void goon_error_print(const Goon_Error *err) {
    if (!err || !err->message) return;

    fprintf(stderr, "error: %s\n", err->message);

    if (err->file && err->line > 0) {
        fprintf(stderr, "  --> %s:%zu:%zu\n", err->file, err->line, err->col);
    } else if (err->line > 0) {
        fprintf(stderr, "  --> %zu:%zu\n", err->line, err->col);
    }

    if (err->source_line) {
        fprintf(stderr, "   |\n");
        fprintf(stderr, "%3zu| %s\n", err->line, err->source_line);
        fprintf(stderr, "   |");
        for (size_t i = 0; i < err->col; i++) {
            fprintf(stderr, " ");
        }
        fprintf(stderr, "^\n");
    }
}

Goon_Value *goon_eval_result(Goon_Ctx *ctx) {
    (void)ctx;
    return last_result;
}

typedef struct {
    char *buf;
    size_t len;
    size_t cap;
} String_Builder;

static void sb_init(String_Builder *sb) {
    sb->buf = malloc(256);
    sb->len = 0;
    sb->cap = 256;
    if (sb->buf) sb->buf[0] = '\0';
}

static void sb_append(String_Builder *sb, const char *str) {
    if (!sb->buf) return;
    size_t add_len = strlen(str);
    while (sb->len + add_len + 1 > sb->cap) {
        sb->cap *= 2;
        sb->buf = realloc(sb->buf, sb->cap);
        if (!sb->buf) return;
    }
    memcpy(sb->buf + sb->len, str, add_len + 1);
    sb->len += add_len;
}

static void sb_append_char(String_Builder *sb, char c) {
    char tmp[2] = {c, '\0'};
    sb_append(sb, tmp);
}

static void json_escape_string(String_Builder *sb, const char *str) {
    sb_append_char(sb, '"');
    while (*str) {
        switch (*str) {
            case '"':  sb_append(sb, "\\\""); break;
            case '\\': sb_append(sb, "\\\\"); break;
            case '\n': sb_append(sb, "\\n"); break;
            case '\r': sb_append(sb, "\\r"); break;
            case '\t': sb_append(sb, "\\t"); break;
            default:   sb_append_char(sb, *str); break;
        }
        str++;
    }
    sb_append_char(sb, '"');
}

static void value_to_json(String_Builder *sb, Goon_Value *val, int indent, int depth);

static void append_indent(String_Builder *sb, int indent, int depth) {
    if (indent <= 0) return;
    for (int i = 0; i < indent * depth; i++) {
        sb_append_char(sb, ' ');
    }
}

static void value_to_json(String_Builder *sb, Goon_Value *val, int indent, int depth) {
    if (!val || val->type == GOON_NIL) {
        sb_append(sb, "null");
        return;
    }

    switch (val->type) {
        case GOON_BOOL:
            sb_append(sb, val->data.boolean ? "true" : "false");
            break;

        case GOON_INT: {
            char num[32];
            snprintf(num, sizeof(num), "%ld", val->data.integer);
            sb_append(sb, num);
            break;
        }

        case GOON_STRING:
            json_escape_string(sb, val->data.string);
            break;

        case GOON_LIST: {
            sb_append_char(sb, '[');
            if (indent > 0 && val->data.list.len > 0) sb_append_char(sb, '\n');
            for (size_t i = 0; i < val->data.list.len; i++) {
                if (indent > 0) append_indent(sb, indent, depth + 1);
                value_to_json(sb, val->data.list.items[i], indent, depth + 1);
                if (i < val->data.list.len - 1) sb_append_char(sb, ',');
                if (indent > 0) sb_append_char(sb, '\n');
            }
            if (indent > 0 && val->data.list.len > 0) append_indent(sb, indent, depth);
            sb_append_char(sb, ']');
            break;
        }

        case GOON_RECORD: {
            sb_append_char(sb, '{');
            Goon_Record_Field *f = val->data.record.fields;
            size_t count = 0;
            Goon_Record_Field *tmp = f;
            while (tmp) { count++; tmp = tmp->next; }
            if (indent > 0 && count > 0) sb_append_char(sb, '\n');
            size_t idx = 0;
            while (f) {
                if (indent > 0) append_indent(sb, indent, depth + 1);
                json_escape_string(sb, f->key);
                sb_append_char(sb, ':');
                if (indent > 0) sb_append_char(sb, ' ');
                value_to_json(sb, f->value, indent, depth + 1);
                if (f->next) sb_append_char(sb, ',');
                if (indent > 0) sb_append_char(sb, '\n');
                f = f->next;
                idx++;
            }
            if (indent > 0 && count > 0) append_indent(sb, indent, depth);
            sb_append_char(sb, '}');
            break;
        }

        default:
            sb_append(sb, "null");
            break;
    }
}

char *goon_to_json(Goon_Value *val) {
    String_Builder sb;
    sb_init(&sb);
    value_to_json(&sb, val, 0, 0);
    return sb.buf;
}

char *goon_to_json_pretty(Goon_Value *val, int indent) {
    String_Builder sb;
    sb_init(&sb);
    value_to_json(&sb, val, indent, 0);
    return sb.buf;
}
