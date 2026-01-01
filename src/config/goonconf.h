#ifndef GOONCONF_H
#define GOONCONF_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

typedef enum {
    GOONCONF_NIL,
    GOONCONF_BOOL,
    GOONCONF_INT,
    GOONCONF_STRING,
    GOONCONF_SYMBOL,
    GOONCONF_PAIR,
    GOONCONF_BUILTIN,
} goonconf_type_t;

typedef struct goonconf_value goonconf_value_t;
typedef struct goonconf_ctx goonconf_ctx_t;

typedef goonconf_value_t *(*goonconf_builtin_fn)(goonconf_ctx_t *ctx, goonconf_value_t *args);

struct goonconf_value {
    goonconf_type_t type;
    struct goonconf_value *next_alloc;
    union {
        bool boolean;
        int64_t integer;
        char *string;
        char *symbol;
        struct {
            goonconf_value_t *car;
            goonconf_value_t *cdr;
        } pair;
        goonconf_builtin_fn builtin;
    } data;
};

typedef struct goonconf_binding {
    char *name;
    goonconf_value_t *value;
    struct goonconf_binding *next;
} goonconf_binding_t;

struct goonconf_ctx {
    goonconf_binding_t *env;
    goonconf_value_t *values;
    char *error;
    void *userdata;
};

goonconf_ctx_t *goonconf_create(void);
void goonconf_destroy(goonconf_ctx_t *ctx);

void goonconf_set_userdata(goonconf_ctx_t *ctx, void *userdata);
void *goonconf_get_userdata(goonconf_ctx_t *ctx);

void goonconf_register(goonconf_ctx_t *ctx, const char *name, goonconf_builtin_fn fn);

bool goonconf_load_file(goonconf_ctx_t *ctx, const char *path);
bool goonconf_load_string(goonconf_ctx_t *ctx, const char *source);

const char *goonconf_get_error(goonconf_ctx_t *ctx);

goonconf_value_t *goonconf_nil(goonconf_ctx_t *ctx);
goonconf_value_t *goonconf_bool(goonconf_ctx_t *ctx, bool val);
goonconf_value_t *goonconf_int(goonconf_ctx_t *ctx, int64_t val);
goonconf_value_t *goonconf_string(goonconf_ctx_t *ctx, const char *val);
goonconf_value_t *goonconf_symbol(goonconf_ctx_t *ctx, const char *val);
goonconf_value_t *goonconf_cons(goonconf_ctx_t *ctx, goonconf_value_t *car, goonconf_value_t *cdr);

bool goonconf_is_nil(goonconf_value_t *val);
bool goonconf_is_bool(goonconf_value_t *val);
bool goonconf_is_int(goonconf_value_t *val);
bool goonconf_is_string(goonconf_value_t *val);
bool goonconf_is_symbol(goonconf_value_t *val);
bool goonconf_is_pair(goonconf_value_t *val);
bool goonconf_is_list(goonconf_value_t *val);

bool goonconf_to_bool(goonconf_value_t *val);
int64_t goonconf_to_int(goonconf_value_t *val);
const char *goonconf_to_string(goonconf_value_t *val);
const char *goonconf_to_symbol(goonconf_value_t *val);

goonconf_value_t *goonconf_car(goonconf_value_t *val);
goonconf_value_t *goonconf_cdr(goonconf_value_t *val);
size_t goonconf_list_length(goonconf_value_t *val);
goonconf_value_t *goonconf_list_nth(goonconf_value_t *val, size_t n);

goonconf_value_t *goonconf_assoc(goonconf_value_t *alist, const char *key);

#endif
