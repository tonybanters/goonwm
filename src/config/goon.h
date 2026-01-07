#ifndef GOON_H
#define GOON_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#define GOON_VERSION "0.1.0"

typedef enum {
    GOON_NIL,
    GOON_BOOL,
    GOON_INT,
    GOON_STRING,
    GOON_LIST,
    GOON_RECORD,
    GOON_BUILTIN,
    GOON_LAMBDA,
} Goon_Type;

typedef struct Goon_Value Goon_Value;
typedef struct Goon_Ctx Goon_Ctx;
typedef struct Goon_Record_Field Goon_Record_Field;
typedef struct Goon_Binding Goon_Binding;

typedef Goon_Value *(*Goon_Builtin_Fn)(Goon_Ctx *ctx, Goon_Value **args, size_t argc);

struct Goon_Record_Field {
    char *key;
    Goon_Value *value;
    Goon_Record_Field *next;
};

struct Goon_Value {
    Goon_Type type;
    struct Goon_Value *next_alloc;
    union {
        bool boolean;
        int64_t integer;
        char *string;
        struct {
            Goon_Value **items;
            size_t len;
            size_t cap;
        } list;
        struct {
            Goon_Record_Field *fields;
        } record;
        Goon_Builtin_Fn builtin;
        struct {
            char **params;
            size_t param_count;
            char *body;
            Goon_Binding *env;
        } lambda;
    } data;
};

typedef struct Goon_Binding {
    char *name;
    Goon_Value *value;
    struct Goon_Binding *next;
} Goon_Binding;

typedef struct {
    char *message;
    char *file;
    size_t line;
    size_t col;
    char *source_line;
} Goon_Error;

struct Goon_Ctx {
    Goon_Binding *env;
    Goon_Value *values;
    Goon_Record_Field *fields;
    Goon_Error error;
    char *base_path;
    void *userdata;
};

Goon_Ctx *goon_create(void);
void goon_destroy(Goon_Ctx *ctx);

void goon_set_userdata(Goon_Ctx *ctx, void *userdata);
void *goon_get_userdata(Goon_Ctx *ctx);

void goon_register(Goon_Ctx *ctx, const char *name, Goon_Builtin_Fn fn);

bool goon_load_file(Goon_Ctx *ctx, const char *path);
bool goon_load_string(Goon_Ctx *ctx, const char *source);

const char *goon_get_error(Goon_Ctx *ctx);
const Goon_Error *goon_get_error_info(Goon_Ctx *ctx);
void goon_error_print(const Goon_Error *err);

Goon_Value *goon_nil(Goon_Ctx *ctx);
Goon_Value *goon_bool(Goon_Ctx *ctx, bool val);
Goon_Value *goon_int(Goon_Ctx *ctx, int64_t val);
Goon_Value *goon_string(Goon_Ctx *ctx, const char *val);
Goon_Value *goon_list(Goon_Ctx *ctx);
Goon_Value *goon_record(Goon_Ctx *ctx);

bool goon_is_nil(Goon_Value *val);
bool goon_is_bool(Goon_Value *val);
bool goon_is_int(Goon_Value *val);
bool goon_is_string(Goon_Value *val);
bool goon_is_list(Goon_Value *val);
bool goon_is_record(Goon_Value *val);

bool goon_to_bool(Goon_Value *val);
int64_t goon_to_int(Goon_Value *val);
const char *goon_to_string(Goon_Value *val);

void goon_list_push(Goon_Ctx *ctx, Goon_Value *list, Goon_Value *item);
size_t goon_list_len(Goon_Value *list);
Goon_Value *goon_list_get(Goon_Value *list, size_t index);

void goon_record_set(Goon_Ctx *ctx, Goon_Value *record, const char *key, Goon_Value *value);
Goon_Value *goon_record_get(Goon_Value *record, const char *key);
Goon_Record_Field *goon_record_fields(Goon_Value *record);

Goon_Value *goon_eval_result(Goon_Ctx *ctx);

char *goon_to_json(Goon_Value *val);
char *goon_to_json_pretty(Goon_Value *val, int indent);

#endif
