module tagion.iwasm.share.utils.bh_assert;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

 

version (BH_DEBUG) {
void bh_assert_internal(int v, const(char)* file_name, int line_number, const(char)* expr_string);
enum string bh_assert(string expr) = ` \
    bh_assert_internal((int)(uintptr_t)(expr), __FILE__, __LINE__, #expr)`;
} else {
enum string bh_assert(string expr) = ` (void)0`;
} /* end of BH_DEBUG */

static if (!HasVersion!"__has_extension") {
enum string __has_extension(string a) = ` 0`;
}



 /* end of _BH_ASSERT_H */
/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */


void bh_assert_internal(int v, const(char)* file_name, int line_number, const(char)* expr_string) {
    if (v)
        return;

    if (!file_name)
        file_name = "NULL FILENAME";

    if (!expr_string)
        expr_string = "NULL EXPR_STRING";

    os_printf("\nASSERTION FAILED: %s, at file %s, line %d\n", expr_string,
              file_name, line_number);

    abort();
}
