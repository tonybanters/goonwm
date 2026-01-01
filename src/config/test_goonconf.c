#include "goonconf.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>

static int tests_passed = 0;
static int tests_failed = 0;

#define TEST(name) static void test_##name(void)
#define RUN(name) do { \
    printf("  %s... ", #name); \
    test_##name(); \
    printf("ok\n"); \
    tests_passed++; \
} while(0)

#define ASSERT(cond) do { \
    if (!(cond)) { \
        printf("FAILED at line %d: %s\n", __LINE__, #cond); \
        tests_failed++; \
        return; \
    } \
} while(0)

static goonconf_value_t *builtin_add(goonconf_ctx_t *ctx, goonconf_value_t *args) {
    int64_t sum = 0;
    while (goonconf_is_pair(args)) {
        goonconf_value_t *v = goonconf_car(args);
        if (goonconf_is_int(v)) {
            sum += goonconf_to_int(v);
        }
        args = goonconf_cdr(args);
    }
    return goonconf_int(ctx, sum);
}

static int callback_count = 0;
static goonconf_value_t *builtin_callback(goonconf_ctx_t *ctx, goonconf_value_t *args) {
    (void)args;
    callback_count++;
    return goonconf_nil(ctx);
}

static char captured_str[256] = {0};
static int64_t captured_int = 0;
static goonconf_value_t *builtin_capture(goonconf_ctx_t *ctx, goonconf_value_t *args) {
    goonconf_value_t *first = goonconf_car(args);
    if (goonconf_is_string(first)) {
        strncpy(captured_str, goonconf_to_string(first), sizeof(captured_str) - 1);
    } else if (goonconf_is_int(first)) {
        captured_int = goonconf_to_int(first);
    }
    return goonconf_nil(ctx);
}

TEST(create_destroy) {
    goonconf_ctx_t *ctx = goonconf_create();
    ASSERT(ctx != NULL);
    goonconf_destroy(ctx);
}

TEST(integers) {
    goonconf_ctx_t *ctx = goonconf_create();
    goonconf_register(ctx, "capture", builtin_capture);

    ASSERT(goonconf_load_string(ctx, "(capture 42)"));
    ASSERT(captured_int == 42);

    ASSERT(goonconf_load_string(ctx, "(capture -123)"));
    ASSERT(captured_int == -123);

    ASSERT(goonconf_load_string(ctx, "(capture 0)"));
    ASSERT(captured_int == 0);

    goonconf_destroy(ctx);
}

TEST(strings) {
    goonconf_ctx_t *ctx = goonconf_create();
    goonconf_register(ctx, "capture", builtin_capture);

    ASSERT(goonconf_load_string(ctx, "(capture \"hello world\")"));
    ASSERT(strcmp(captured_str, "hello world") == 0);

    ASSERT(goonconf_load_string(ctx, "(capture \"line1\\nline2\")"));
    ASSERT(strcmp(captured_str, "line1\nline2") == 0);

    ASSERT(goonconf_load_string(ctx, "(capture \"tab\\there\")"));
    ASSERT(strcmp(captured_str, "tab\there") == 0);

    goonconf_destroy(ctx);
}

TEST(booleans) {
    goonconf_ctx_t *ctx = goonconf_create();

    goonconf_value_t *t = goonconf_bool(ctx, true);
    goonconf_value_t *f = goonconf_bool(ctx, false);

    ASSERT(goonconf_is_bool(t));
    ASSERT(goonconf_is_bool(f));
    ASSERT(goonconf_to_bool(t) == true);
    ASSERT(goonconf_to_bool(f) == false);

    goonconf_destroy(ctx);
}

TEST(symbols) {
    goonconf_ctx_t *ctx = goonconf_create();

    goonconf_value_t *sym = goonconf_symbol(ctx, "my-symbol");
    ASSERT(goonconf_is_symbol(sym));
    ASSERT(strcmp(goonconf_to_symbol(sym), "my-symbol") == 0);

    goonconf_destroy(ctx);
}

TEST(lists) {
    goonconf_ctx_t *ctx = goonconf_create();

    goonconf_value_t *nil = goonconf_nil(ctx);
    goonconf_value_t *one = goonconf_int(ctx, 1);
    goonconf_value_t *two = goonconf_int(ctx, 2);

    goonconf_value_t *list = goonconf_cons(ctx, one, goonconf_cons(ctx, two, nil));

    ASSERT(goonconf_is_pair(list));
    ASSERT(goonconf_is_list(list));
    ASSERT(goonconf_list_length(list) == 2);
    ASSERT(goonconf_to_int(goonconf_list_nth(list, 0)) == 1);
    ASSERT(goonconf_to_int(goonconf_list_nth(list, 1)) == 2);

    goonconf_destroy(ctx);
}

TEST(define) {
    goonconf_ctx_t *ctx = goonconf_create();
    goonconf_register(ctx, "capture", builtin_capture);

    ASSERT(goonconf_load_string(ctx, "(define x 100)"));
    ASSERT(goonconf_load_string(ctx, "(capture x)"));
    ASSERT(captured_int == 100);

    ASSERT(goonconf_load_string(ctx, "(define y \"test\")"));
    ASSERT(goonconf_load_string(ctx, "(capture y)"));
    ASSERT(strcmp(captured_str, "test") == 0);

    goonconf_destroy(ctx);
}

TEST(builtin_functions) {
    goonconf_ctx_t *ctx = goonconf_create();
    goonconf_register(ctx, "+", builtin_add);
    goonconf_register(ctx, "capture", builtin_capture);

    ASSERT(goonconf_load_string(ctx, "(capture (+ 1 2 3))"));
    ASSERT(captured_int == 6);

    ASSERT(goonconf_load_string(ctx, "(capture (+ 10 -5))"));
    ASSERT(captured_int == 5);

    goonconf_destroy(ctx);
}

TEST(quote) {
    goonconf_ctx_t *ctx = goonconf_create();

    ASSERT(goonconf_load_string(ctx, "(define mods '(mod1 shift))"));

    goonconf_destroy(ctx);
}

TEST(if_expression) {
    goonconf_ctx_t *ctx = goonconf_create();
    goonconf_register(ctx, "capture", builtin_capture);

    ASSERT(goonconf_load_string(ctx, "(capture (if #t 1 2))"));
    ASSERT(captured_int == 1);

    ASSERT(goonconf_load_string(ctx, "(capture (if #f 1 2))"));
    ASSERT(captured_int == 2);

    goonconf_destroy(ctx);
}

TEST(dotted_pairs) {
    goonconf_ctx_t *ctx = goonconf_create();

    ASSERT(goonconf_load_string(ctx, "(define pair '(a . b))"));

    goonconf_destroy(ctx);
}

TEST(comments) {
    goonconf_ctx_t *ctx = goonconf_create();
    goonconf_register(ctx, "capture", builtin_capture);

    ASSERT(goonconf_load_string(ctx,
        "; this is a comment\n"
        "(capture 42) ; inline comment\n"
        "; another comment\n"
    ));
    ASSERT(captured_int == 42);

    goonconf_destroy(ctx);
}

TEST(multiple_statements) {
    goonconf_ctx_t *ctx = goonconf_create();
    callback_count = 0;
    goonconf_register(ctx, "callback", builtin_callback);

    ASSERT(goonconf_load_string(ctx,
        "(callback)\n"
        "(callback)\n"
        "(callback)\n"
    ));
    ASSERT(callback_count == 3);

    goonconf_destroy(ctx);
}

TEST(list_expression) {
    goonconf_ctx_t *ctx = goonconf_create();
    goonconf_register(ctx, "capture", builtin_capture);

    ASSERT(goonconf_load_string(ctx,
        "(define x 1)\n"
        "(define y 2)\n"
        "(define mylist (list x y 3))\n"
    ));

    goonconf_destroy(ctx);
}

TEST(assoc_list) {
    goonconf_ctx_t *ctx = goonconf_create();

    goonconf_value_t *nil = goonconf_nil(ctx);
    goonconf_value_t *pair1 = goonconf_cons(ctx, goonconf_symbol(ctx, "class"),
                                            goonconf_string(ctx, "Firefox"));
    goonconf_value_t *pair2 = goonconf_cons(ctx, goonconf_symbol(ctx, "tag"),
                                            goonconf_int(ctx, 8));
    goonconf_value_t *alist = goonconf_cons(ctx, pair1,
                              goonconf_cons(ctx, pair2, nil));

    goonconf_value_t *found = goonconf_assoc(alist, "class");
    ASSERT(found != NULL);
    ASSERT(goonconf_is_string(found));
    ASSERT(strcmp(goonconf_to_string(found), "Firefox") == 0);

    found = goonconf_assoc(alist, "tag");
    ASSERT(found != NULL);
    ASSERT(goonconf_to_int(found) == 8);

    found = goonconf_assoc(alist, "notfound");
    ASSERT(found == NULL);

    goonconf_destroy(ctx);
}

TEST(userdata) {
    goonconf_ctx_t *ctx = goonconf_create();
    int mydata = 12345;

    goonconf_set_userdata(ctx, &mydata);
    ASSERT(goonconf_get_userdata(ctx) == &mydata);
    ASSERT(*(int*)goonconf_get_userdata(ctx) == 12345);

    goonconf_destroy(ctx);
}

TEST(unicode_strings) {
    goonconf_ctx_t *ctx = goonconf_create();
    goonconf_register(ctx, "capture", builtin_capture);

    ASSERT(goonconf_load_string(ctx, "(capture \"󰊯\")"));
    ASSERT(strcmp(captured_str, "󰊯") == 0);

    goonconf_destroy(ctx);
}

TEST(symbol_with_special_chars) {
    goonconf_ctx_t *ctx = goonconf_create();

    ASSERT(goonconf_load_string(ctx,
        "(define set-terminal! 1)\n"
        "(define border-focused! 2)\n"
        "(define toggle-gaps 3)\n"
    ));

    goonconf_destroy(ctx);
}

int main(void) {
    printf("Running goonconf tests:\n");

    RUN(create_destroy);
    RUN(integers);
    RUN(strings);
    RUN(booleans);
    RUN(symbols);
    RUN(lists);
    RUN(define);
    RUN(builtin_functions);
    RUN(quote);
    RUN(if_expression);
    RUN(dotted_pairs);
    RUN(comments);
    RUN(multiple_statements);
    RUN(list_expression);
    RUN(assoc_list);
    RUN(userdata);
    RUN(unicode_strings);
    RUN(symbol_with_special_chars);

    printf("\nResults: %d passed, %d failed\n", tests_passed, tests_failed);
    return tests_failed > 0 ? 1 : 0;
}
