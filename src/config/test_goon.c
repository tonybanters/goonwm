#include "goon.h"
#include <stdio.h>
#include <string.h>

static Goon_Value *builtin_tag_binds(Goon_Ctx *ctx, Goon_Value **args, size_t argc) {
    if (argc < 4) return goon_list(ctx);

    Goon_Value *mods = args[0];
    const char *action = goon_to_string(args[1]);
    int64_t start = goon_to_int(args[2]);
    int64_t end = goon_to_int(args[3]);

    if (!action) return goon_list(ctx);

    Goon_Value *result = goon_list(ctx);

    for (int64_t i = start; i <= end; i++) {
        Goon_Value *binding = goon_record(ctx);

        goon_record_set(ctx, binding, "mod", mods);

        char key_str[2];
        key_str[0] = '0' + (i % 10);
        key_str[1] = '\0';
        goon_record_set(ctx, binding, "key", goon_string(ctx, key_str));

        goon_record_set(ctx, binding, "action", goon_string(ctx, action));
        goon_record_set(ctx, binding, "arg", goon_int(ctx, i - 1));

        goon_list_push(ctx, result, binding);
    }

    return result;
}

static void print_value(Goon_Value *val, int indent) {
    if (!val) {
        printf("null");
        return;
    }

    switch (val->type) {
        case GOON_NIL:
            printf("nil");
            break;
        case GOON_BOOL:
            printf("%s", val->data.boolean ? "true" : "false");
            break;
        case GOON_INT:
            printf("%ld", val->data.integer);
            break;
        case GOON_STRING:
            printf("\"%s\"", val->data.string);
            break;
        case GOON_LIST:
            printf("[\n");
            for (size_t i = 0; i < val->data.list.len; i++) {
                for (int j = 0; j < indent + 2; j++) printf(" ");
                print_value(val->data.list.items[i], indent + 2);
                if (i < val->data.list.len - 1) printf(",");
                printf("\n");
            }
            for (int j = 0; j < indent; j++) printf(" ");
            printf("]");
            break;
        case GOON_RECORD: {
            printf("{\n");
            Goon_Record_Field *f = val->data.record.fields;
            while (f) {
                for (int j = 0; j < indent + 2; j++) printf(" ");
                printf("%s = ", f->key);
                print_value(f->value, indent + 2);
                if (f->next) printf(";");
                printf("\n");
                f = f->next;
            }
            for (int j = 0; j < indent; j++) printf(" ");
            printf("}");
            break;
        }
        default:
            printf("<unknown>");
    }
}

int main(int argc, char **argv) {
    const char *test_source =
        "let terminal = \"alacritty\";\n"
        "let border_width = 2;\n"
        "let is_laptop = false;\n"
        "\n"
        "let colors = {\n"
        "    bg = \"#1e1e2e\";\n"
        "    fg = \"#cdd6f4\";\n"
        "    blue = \"#89b4fa\";\n"
        "};\n"
        "\n"
        "{\n"
        "    terminal = terminal;\n"
        "    border = border_width;\n"
        "    gaps = is_laptop ? 5 : 10;\n"
        "    bg_color = colors.bg;\n"
        "    tags = [\"1\", \"2\", \"3\", \"4\", \"5\"];\n"
        "    keys = [\n"
        "        { mod = [\"mod1\"]; key = \"Return\"; action = \"spawn-terminal\"; },\n"
        "        { mod = [\"mod1\"]; key = \"q\"; action = \"kill-client\"; },\n"
        "        ...tag_binds([\"mod1\"], \"view-tag\", 1, 5),\n"
        "    ];\n"
        "}\n";

    Goon_Ctx *ctx = goon_create();
    if (!ctx) {
        fprintf(stderr, "failed to create context\n");
        return 1;
    }

    goon_register(ctx, "tag_binds", builtin_tag_binds);

    printf("parsing:\n%s\n", test_source);
    printf("---\n");

    if (!goon_load_string(ctx, test_source)) {
        fprintf(stderr, "parse error: %s\n", goon_get_error(ctx));
        goon_destroy(ctx);
        return 1;
    }

    Goon_Value *result = goon_eval_result(ctx);
    if (result) {
        printf("result:\n");
        print_value(result, 0);
        printf("\n");
    }

    if (argc > 1) {
        printf("\n--- loading file: %s ---\n", argv[1]);

        Goon_Ctx *file_ctx = goon_create();
        goon_register(file_ctx, "tag_binds", builtin_tag_binds);

        if (!goon_load_file(file_ctx, argv[1])) {
            fprintf(stderr, "file parse error: %s\n", goon_get_error(file_ctx));
            goon_destroy(file_ctx);
            goon_destroy(ctx);
            return 1;
        }

        Goon_Value *file_result = goon_eval_result(file_ctx);
        if (file_result) {
            printf("file result:\n");
            print_value(file_result, 0);
            printf("\n");
        }

        goon_destroy(file_ctx);
    }

    goon_destroy(ctx);
    return 0;
}
