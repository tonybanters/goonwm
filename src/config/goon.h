#ifndef GOON_H
#define GOON_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

typedef enum {
    GOON_NIL,
    GOON_BOOL,
    GOON_INT,
    GOON_STRING,
    GOON_LIST,
    GOON_RECORD,
    GOON_BUILTIN,
} goon_type_t;

typedef struct goon_value goon_value_t;
typedef struct goon_ctx goon_ctx_t;
typedef struct goon_record_field goon_record_field_t;

typedef goon_value_t *(*goon_builtin_fn)(goon_ctx_t *ctx, goon_value_t **args, size_t argc);

struct goon_record_field {
    char *key;
    goon_value_t *value;
    goon_record_field_t *next;
};

struct goon_value {
    goon_type_t type;
    struct goon_value *next_alloc;
    union {
        bool boolean;
        int64_t integer;
        char *string;
        struct {
            goon_value_t **items;
            size_t len;
            size_t cap;
        } list;
        struct {
            goon_record_field_t *fields;
        } record;
        goon_builtin_fn builtin;
    } data;
};

typedef struct goon_binding {
    char *name;
    goon_value_t *value;
    struct goon_binding *next;
} goon_binding_t;

struct goon_ctx {
    goon_binding_t *env;
    goon_value_t *values;
    goon_record_field_t *fields;
    char *error;
    char *base_path;
    void *userdata;
};

goon_ctx_t *goon_create(void);
void goon_destroy(goon_ctx_t *ctx);

void goon_set_userdata(goon_ctx_t *ctx, void *userdata);
void *goon_get_userdata(goon_ctx_t *ctx);

void goon_register(goon_ctx_t *ctx, const char *name, goon_builtin_fn fn);

bool goon_load_file(goon_ctx_t *ctx, const char *path);
bool goon_load_string(goon_ctx_t *ctx, const char *source);

const char *goon_get_error(goon_ctx_t *ctx);

goon_value_t *goon_nil(goon_ctx_t *ctx);
goon_value_t *goon_bool(goon_ctx_t *ctx, bool val);
goon_value_t *goon_int(goon_ctx_t *ctx, int64_t val);
goon_value_t *goon_string(goon_ctx_t *ctx, const char *val);
goon_value_t *goon_list(goon_ctx_t *ctx);
goon_value_t *goon_record(goon_ctx_t *ctx);

bool goon_is_nil(goon_value_t *val);
bool goon_is_bool(goon_value_t *val);
bool goon_is_int(goon_value_t *val);
bool goon_is_string(goon_value_t *val);
bool goon_is_list(goon_value_t *val);
bool goon_is_record(goon_value_t *val);

bool goon_to_bool(goon_value_t *val);
int64_t goon_to_int(goon_value_t *val);
const char *goon_to_string(goon_value_t *val);

void goon_list_push(goon_ctx_t *ctx, goon_value_t *list, goon_value_t *item);
size_t goon_list_len(goon_value_t *list);
goon_value_t *goon_list_get(goon_value_t *list, size_t index);

void goon_record_set(goon_ctx_t *ctx, goon_value_t *record, const char *key, goon_value_t *value);
goon_value_t *goon_record_get(goon_value_t *record, const char *key);
goon_record_field_t *goon_record_fields(goon_value_t *record);

goon_value_t *goon_eval_result(goon_ctx_t *ctx);

#endif
