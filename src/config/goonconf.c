#define _POSIX_C_SOURCE 200809L
#include "goonconf.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>

typedef enum {
    TOK_EOF,
    TOK_LPAREN,
    TOK_RPAREN,
    TOK_QUOTE,
    TOK_DOT,
    TOK_INT,
    TOK_STRING,
    TOK_SYMBOL,
    TOK_BOOL,
} token_type_t;

typedef struct {
    token_type_t type;
    union {
        int64_t integer;
        char *string;
        bool boolean;
    } data;
} token_t;

typedef struct {
    const char *src;
    size_t pos;
    size_t len;
    token_t current;
    char *error;
} lexer_t;

static void lexer_init(lexer_t *lex, const char *src) {
    lex->src = src;
    lex->pos = 0;
    lex->len = strlen(src);
    lex->current.type = TOK_EOF;
    lex->error = NULL;
}

static void lexer_skip_whitespace(lexer_t *lex) {
    while (lex->pos < lex->len) {
        char c = lex->src[lex->pos];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == ',') {
            lex->pos++;
        } else if (c == ';') {
            while (lex->pos < lex->len && lex->src[lex->pos] != '\n') {
                lex->pos++;
            }
        } else {
            break;
        }
    }
}

static bool is_symbol_char(char c) {
    if (isalnum(c)) return true;
    if (c == '-' || c == '_' || c == '!' || c == '?' || c == '+' ||
        c == '*' || c == '/' || c == '<' || c == '>' || c == '=' ||
        c == ':') return true;
    return false;
}

static char *strdup_range(const char *start, size_t len) {
    char *s = malloc(len + 1);
    if (!s) return NULL;
    memcpy(s, start, len);
    s[len] = '\0';
    return s;
}

static bool lexer_next(lexer_t *lex) {
    lexer_skip_whitespace(lex);

    if (lex->pos >= lex->len) {
        lex->current.type = TOK_EOF;
        return true;
    }

    char c = lex->src[lex->pos];

    if (c == '(') {
        lex->current.type = TOK_LPAREN;
        lex->pos++;
        return true;
    }

    if (c == ')') {
        lex->current.type = TOK_RPAREN;
        lex->pos++;
        return true;
    }

    if (c == '\'') {
        lex->current.type = TOK_QUOTE;
        lex->pos++;
        return true;
    }

    if (c == '.') {
        if (lex->pos + 1 < lex->len && !is_symbol_char(lex->src[lex->pos + 1])) {
            lex->current.type = TOK_DOT;
            lex->pos++;
            return true;
        }
    }

    if (c == '#') {
        if (lex->pos + 1 < lex->len) {
            char next = lex->src[lex->pos + 1];
            if (next == 't') {
                lex->current.type = TOK_BOOL;
                lex->current.data.boolean = true;
                lex->pos += 2;
                return true;
            } else if (next == 'f') {
                lex->current.type = TOK_BOOL;
                lex->current.data.boolean = false;
                lex->pos += 2;
                return true;
            }
        }
    }

    if (c == '"') {
        lex->pos++;
        size_t buf_size = 256;
        size_t buf_len = 0;
        char *buf = malloc(buf_size);
        if (!buf) return false;

        while (lex->pos < lex->len && lex->src[lex->pos] != '"') {
            char ch = lex->src[lex->pos];
            if (ch == '\\' && lex->pos + 1 < lex->len) {
                lex->pos++;
                ch = lex->src[lex->pos];
                switch (ch) {
                    case 'n': ch = '\n'; break;
                    case 't': ch = '\t'; break;
                    case 'r': ch = '\r'; break;
                    case '\\': ch = '\\'; break;
                    case '"': ch = '"'; break;
                    default: break;
                }
            }
            if (buf_len + 1 >= buf_size) {
                buf_size *= 2;
                buf = realloc(buf, buf_size);
                if (!buf) return false;
            }
            buf[buf_len++] = ch;
            lex->pos++;
        }

        if (lex->pos >= lex->len) {
            free(buf);
            lex->error = strdup("unterminated string");
            return false;
        }

        lex->pos++;
        buf[buf_len] = '\0';
        lex->current.type = TOK_STRING;
        lex->current.data.string = buf;
        return true;
    }

    if (isdigit(c) || (c == '-' && lex->pos + 1 < lex->len && isdigit(lex->src[lex->pos + 1]))) {
        int sign = 1;
        if (c == '-') {
            sign = -1;
            lex->pos++;
        }
        int64_t val = 0;
        while (lex->pos < lex->len && isdigit(lex->src[lex->pos])) {
            val = val * 10 + (lex->src[lex->pos] - '0');
            lex->pos++;
        }
        lex->current.type = TOK_INT;
        lex->current.data.integer = val * sign;
        return true;
    }

    if (is_symbol_char(c) || c == '-') {
        size_t start = lex->pos;
        while (lex->pos < lex->len && is_symbol_char(lex->src[lex->pos])) {
            lex->pos++;
        }
        lex->current.type = TOK_SYMBOL;
        lex->current.data.string = strdup_range(lex->src + start, lex->pos - start);
        return true;
    }

    lex->error = strdup("unexpected character");
    return false;
}

static goonconf_value_t *alloc_value(goonconf_ctx_t *ctx) {
    goonconf_value_t *val = malloc(sizeof(goonconf_value_t));
    if (!val) return NULL;
    val->type = GOONCONF_NIL;
    val->next_alloc = ctx->values;
    ctx->values = val;
    return val;
}

goonconf_value_t *goonconf_nil(goonconf_ctx_t *ctx) {
    goonconf_value_t *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOONCONF_NIL;
    return val;
}

goonconf_value_t *goonconf_bool(goonconf_ctx_t *ctx, bool b) {
    goonconf_value_t *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOONCONF_BOOL;
    val->data.boolean = b;
    return val;
}

goonconf_value_t *goonconf_int(goonconf_ctx_t *ctx, int64_t i) {
    goonconf_value_t *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOONCONF_INT;
    val->data.integer = i;
    return val;
}

goonconf_value_t *goonconf_string(goonconf_ctx_t *ctx, const char *s) {
    goonconf_value_t *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOONCONF_STRING;
    val->data.string = strdup(s);
    return val;
}

goonconf_value_t *goonconf_symbol(goonconf_ctx_t *ctx, const char *s) {
    goonconf_value_t *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOONCONF_SYMBOL;
    val->data.symbol = strdup(s);
    return val;
}

goonconf_value_t *goonconf_cons(goonconf_ctx_t *ctx, goonconf_value_t *car, goonconf_value_t *cdr) {
    goonconf_value_t *val = alloc_value(ctx);
    if (!val) return NULL;
    val->type = GOONCONF_PAIR;
    val->data.pair.car = car;
    val->data.pair.cdr = cdr;
    return val;
}

bool goonconf_is_nil(goonconf_value_t *val) {
    return val == NULL || val->type == GOONCONF_NIL;
}

bool goonconf_is_bool(goonconf_value_t *val) {
    return val != NULL && val->type == GOONCONF_BOOL;
}

bool goonconf_is_int(goonconf_value_t *val) {
    return val != NULL && val->type == GOONCONF_INT;
}

bool goonconf_is_string(goonconf_value_t *val) {
    return val != NULL && val->type == GOONCONF_STRING;
}

bool goonconf_is_symbol(goonconf_value_t *val) {
    return val != NULL && val->type == GOONCONF_SYMBOL;
}

bool goonconf_is_pair(goonconf_value_t *val) {
    return val != NULL && val->type == GOONCONF_PAIR;
}

bool goonconf_is_list(goonconf_value_t *val) {
    while (val != NULL) {
        if (val->type == GOONCONF_NIL) return true;
        if (val->type != GOONCONF_PAIR) return false;
        val = val->data.pair.cdr;
    }
    return true;
}

bool goonconf_to_bool(goonconf_value_t *val) {
    if (val == NULL) return false;
    if (val->type == GOONCONF_BOOL) return val->data.boolean;
    if (val->type == GOONCONF_NIL) return false;
    return true;
}

int64_t goonconf_to_int(goonconf_value_t *val) {
    if (val == NULL || val->type != GOONCONF_INT) return 0;
    return val->data.integer;
}

const char *goonconf_to_string(goonconf_value_t *val) {
    if (val == NULL || val->type != GOONCONF_STRING) return NULL;
    return val->data.string;
}

const char *goonconf_to_symbol(goonconf_value_t *val) {
    if (val == NULL || val->type != GOONCONF_SYMBOL) return NULL;
    return val->data.symbol;
}

goonconf_value_t *goonconf_car(goonconf_value_t *val) {
    if (val == NULL || val->type != GOONCONF_PAIR) return NULL;
    return val->data.pair.car;
}

goonconf_value_t *goonconf_cdr(goonconf_value_t *val) {
    if (val == NULL || val->type != GOONCONF_PAIR) return NULL;
    return val->data.pair.cdr;
}

size_t goonconf_list_length(goonconf_value_t *val) {
    size_t len = 0;
    while (val != NULL && val->type == GOONCONF_PAIR) {
        len++;
        val = val->data.pair.cdr;
    }
    return len;
}

goonconf_value_t *goonconf_list_nth(goonconf_value_t *val, size_t n) {
    while (val != NULL && val->type == GOONCONF_PAIR && n > 0) {
        val = val->data.pair.cdr;
        n--;
    }
    if (val == NULL || val->type != GOONCONF_PAIR) return NULL;
    return val->data.pair.car;
}

goonconf_value_t *goonconf_assoc(goonconf_value_t *alist, const char *key) {
    while (alist != NULL && alist->type == GOONCONF_PAIR) {
        goonconf_value_t *pair = alist->data.pair.car;
        if (pair != NULL && pair->type == GOONCONF_PAIR) {
            goonconf_value_t *k = pair->data.pair.car;
            if (k != NULL && k->type == GOONCONF_SYMBOL && strcmp(k->data.symbol, key) == 0) {
                return pair->data.pair.cdr;
            }
        }
        alist = alist->data.pair.cdr;
    }
    return NULL;
}

static goonconf_value_t *lookup(goonconf_ctx_t *ctx, const char *name) {
    goonconf_binding_t *b = ctx->env;
    while (b != NULL) {
        if (strcmp(b->name, name) == 0) {
            return b->value;
        }
        b = b->next;
    }
    return NULL;
}

static void define(goonconf_ctx_t *ctx, const char *name, goonconf_value_t *value) {
    goonconf_binding_t *b = ctx->env;
    while (b != NULL) {
        if (strcmp(b->name, name) == 0) {
            b->value = value;
            return;
        }
        b = b->next;
    }
    b = malloc(sizeof(goonconf_binding_t));
    if (!b) return;
    b->name = strdup(name);
    b->value = value;
    b->next = ctx->env;
    ctx->env = b;
}

typedef struct {
    goonconf_ctx_t *ctx;
    lexer_t *lex;
} parser_t;

static goonconf_value_t *parse_expr(parser_t *p);

static goonconf_value_t *parse_list(parser_t *p) {
    if (!lexer_next(p->lex)) return NULL;

    if (p->lex->current.type == TOK_RPAREN) {
        if (!lexer_next(p->lex)) return NULL;
        return goonconf_nil(p->ctx);
    }

    goonconf_value_t *first = parse_expr(p);
    if (!first) return NULL;

    if (p->lex->current.type == TOK_DOT) {
        if (!lexer_next(p->lex)) return NULL;
        goonconf_value_t *second = parse_expr(p);
        if (!second) return NULL;
        if (p->lex->current.type != TOK_RPAREN) {
            p->lex->error = strdup("expected ) after dotted pair");
            return NULL;
        }
        if (!lexer_next(p->lex)) return NULL;
        return goonconf_cons(p->ctx, first, second);
    }

    goonconf_value_t *tail = NULL;
    goonconf_value_t *head = goonconf_cons(p->ctx, first, goonconf_nil(p->ctx));
    tail = head;

    while (p->lex->current.type != TOK_RPAREN && p->lex->current.type != TOK_EOF) {
        goonconf_value_t *elem = parse_expr(p);
        if (!elem) return NULL;

        if (p->lex->current.type == TOK_DOT) {
            if (!lexer_next(p->lex)) return NULL;
            goonconf_value_t *final = parse_expr(p);
            if (!final) return NULL;
            tail->data.pair.cdr = final;
            if (p->lex->current.type != TOK_RPAREN) {
                p->lex->error = strdup("expected ) after dotted pair");
                return NULL;
            }
            if (!lexer_next(p->lex)) return NULL;
            return head;
        }

        goonconf_value_t *cell = goonconf_cons(p->ctx, elem, goonconf_nil(p->ctx));
        tail->data.pair.cdr = cell;
        tail = cell;
    }

    if (p->lex->current.type != TOK_RPAREN) {
        p->lex->error = strdup("unterminated list");
        return NULL;
    }

    if (!lexer_next(p->lex)) return NULL;
    return head;
}

static goonconf_value_t *parse_expr(parser_t *p) {
    token_t tok = p->lex->current;

    switch (tok.type) {
        case TOK_EOF:
            return NULL;

        case TOK_LPAREN:
            return parse_list(p);

        case TOK_QUOTE: {
            if (!lexer_next(p->lex)) return NULL;
            goonconf_value_t *quoted = parse_expr(p);
            if (!quoted) return NULL;
            return goonconf_cons(p->ctx, goonconf_symbol(p->ctx, "quote"),
                   goonconf_cons(p->ctx, quoted, goonconf_nil(p->ctx)));
        }

        case TOK_INT: {
            goonconf_value_t *val = goonconf_int(p->ctx, tok.data.integer);
            if (!lexer_next(p->lex)) return NULL;
            return val;
        }

        case TOK_STRING: {
            goonconf_value_t *val = goonconf_string(p->ctx, tok.data.string);
            free(tok.data.string);
            if (!lexer_next(p->lex)) return NULL;
            return val;
        }

        case TOK_SYMBOL: {
            goonconf_value_t *val = goonconf_symbol(p->ctx, tok.data.string);
            free(tok.data.string);
            if (!lexer_next(p->lex)) return NULL;
            return val;
        }

        case TOK_BOOL: {
            goonconf_value_t *val = goonconf_bool(p->ctx, tok.data.boolean);
            if (!lexer_next(p->lex)) return NULL;
            return val;
        }

        case TOK_RPAREN:
            p->lex->error = strdup("unexpected )");
            return NULL;

        case TOK_DOT:
            p->lex->error = strdup("unexpected .");
            return NULL;

        default:
            return NULL;
    }
}

static goonconf_value_t *eval(goonconf_ctx_t *ctx, goonconf_value_t *expr);

static goonconf_value_t *eval_list(goonconf_ctx_t *ctx, goonconf_value_t *list) {
    if (goonconf_is_nil(list)) {
        return goonconf_nil(ctx);
    }
    goonconf_value_t *head = eval(ctx, goonconf_car(list));
    goonconf_value_t *tail = eval_list(ctx, goonconf_cdr(list));
    return goonconf_cons(ctx, head, tail);
}

static goonconf_value_t *eval(goonconf_ctx_t *ctx, goonconf_value_t *expr) {
    if (expr == NULL) return goonconf_nil(ctx);

    switch (expr->type) {
        case GOONCONF_NIL:
        case GOONCONF_BOOL:
        case GOONCONF_INT:
        case GOONCONF_STRING:
        case GOONCONF_BUILTIN:
            return expr;

        case GOONCONF_SYMBOL: {
            goonconf_value_t *val = lookup(ctx, expr->data.symbol);
            if (val == NULL) {
                return expr;
            }
            return val;
        }

        case GOONCONF_PAIR: {
            goonconf_value_t *first = goonconf_car(expr);

            if (goonconf_is_symbol(first)) {
                const char *name = first->data.symbol;

                if (strcmp(name, "quote") == 0) {
                    return goonconf_car(goonconf_cdr(expr));
                }

                if (strcmp(name, "define") == 0) {
                    goonconf_value_t *sym = goonconf_car(goonconf_cdr(expr));
                    goonconf_value_t *val = eval(ctx, goonconf_car(goonconf_cdr(goonconf_cdr(expr))));
                    if (goonconf_is_symbol(sym)) {
                        define(ctx, sym->data.symbol, val);
                    }
                    return goonconf_nil(ctx);
                }

                if (strcmp(name, "if") == 0) {
                    goonconf_value_t *cond = eval(ctx, goonconf_car(goonconf_cdr(expr)));
                    if (goonconf_to_bool(cond)) {
                        return eval(ctx, goonconf_car(goonconf_cdr(goonconf_cdr(expr))));
                    } else {
                        goonconf_value_t *else_branch = goonconf_car(goonconf_cdr(goonconf_cdr(goonconf_cdr(expr))));
                        if (!goonconf_is_nil(else_branch)) {
                            return eval(ctx, else_branch);
                        }
                        return goonconf_nil(ctx);
                    }
                }

                if (strcmp(name, "list") == 0) {
                    return eval_list(ctx, goonconf_cdr(expr));
                }
            }

            goonconf_value_t *fn = eval(ctx, first);
            if (fn != NULL && fn->type == GOONCONF_BUILTIN) {
                goonconf_value_t *args = eval_list(ctx, goonconf_cdr(expr));
                return fn->data.builtin(ctx, args);
            }

            return expr;
        }

        default:
            return expr;
    }
}

goonconf_ctx_t *goonconf_create(void) {
    goonconf_ctx_t *ctx = malloc(sizeof(goonconf_ctx_t));
    if (!ctx) return NULL;
    ctx->env = NULL;
    ctx->values = NULL;
    ctx->error = NULL;
    ctx->userdata = NULL;
    return ctx;
}

void goonconf_destroy(goonconf_ctx_t *ctx) {
    if (!ctx) return;

    goonconf_binding_t *b = ctx->env;
    while (b != NULL) {
        goonconf_binding_t *next = b->next;
        free(b->name);
        free(b);
        b = next;
    }

    goonconf_value_t *v = ctx->values;
    while (v != NULL) {
        goonconf_value_t *next = v->next_alloc;
        if (v->type == GOONCONF_STRING && v->data.string) {
            free(v->data.string);
        } else if (v->type == GOONCONF_SYMBOL && v->data.symbol) {
            free(v->data.symbol);
        }
        free(v);
        v = next;
    }

    if (ctx->error) free(ctx->error);
    free(ctx);
}

void goonconf_set_userdata(goonconf_ctx_t *ctx, void *userdata) {
    ctx->userdata = userdata;
}

void *goonconf_get_userdata(goonconf_ctx_t *ctx) {
    return ctx->userdata;
}

void goonconf_register(goonconf_ctx_t *ctx, const char *name, goonconf_builtin_fn fn) {
    goonconf_value_t *val = alloc_value(ctx);
    if (!val) return;
    val->type = GOONCONF_BUILTIN;
    val->data.builtin = fn;
    define(ctx, name, val);
}

bool goonconf_load_string(goonconf_ctx_t *ctx, const char *source) {
    lexer_t lex;
    lexer_init(&lex, source);

    parser_t parser;
    parser.ctx = ctx;
    parser.lex = &lex;

    if (!lexer_next(&lex)) {
        if (ctx->error) free(ctx->error);
        ctx->error = lex.error;
        return false;
    }

    while (lex.current.type != TOK_EOF) {
        goonconf_value_t *expr = parse_expr(&parser);
        if (!expr) {
            if (lex.error) {
                if (ctx->error) free(ctx->error);
                ctx->error = lex.error;
            }
            return false;
        }
        eval(ctx, expr);
    }

    return true;
}

bool goonconf_load_file(goonconf_ctx_t *ctx, const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) {
        if (ctx->error) free(ctx->error);
        ctx->error = strdup("could not open file");
        return false;
    }

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);

    char *source = malloc(size + 1);
    if (!source) {
        fclose(f);
        if (ctx->error) free(ctx->error);
        ctx->error = strdup("out of memory");
        return false;
    }

    size_t read_size = fread(source, 1, size, f);
    source[read_size] = '\0';
    fclose(f);

    bool result = goonconf_load_string(ctx, source);
    free(source);
    return result;
}

const char *goonconf_get_error(goonconf_ctx_t *ctx) {
    return ctx->error;
}
