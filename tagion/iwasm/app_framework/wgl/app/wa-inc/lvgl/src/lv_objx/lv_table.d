module lv_table;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_table.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *      INCLUDES
 *********************/
version (LV_CONF_INCLUDE_SIMPLE) {
public import lv_conf;
} else {
public import .........lv_conf;
}

static if (LV_USE_TABLE != 0) {

/*Testing of dependencies*/
static if (LV_USE_LABEL == 0) {
static assert(0, "lv_table: lv_label is required. Enable it in lv_conf.h (LV_USE_LABEL  1) ");
}

public import ...lv_core.lv_obj;
public import lv_label;

/*********************
 *      DEFINES
 *********************/
version (LV_TABLE_COL_MAX) {} else {
enum LV_TABLE_COL_MAX = 12;
}

enum LV_TABLE_CELL_STYLE_CNT = 4;
/**********************
 *      TYPEDEFS
 **********************/

/**
 * Internal table cell format structure.
 * 
 * Use the `lv_table` APIs instead.
 */
union _Lv_table_cell_format_t {
    struct _S {
        ubyte align_;/*: 2 !!*/
        ubyte right_merge;/*: 1 !!*/
        ubyte type;/*: 2 !!*/
        ubyte crop;/*: 1 !!*/
    }_S s;
    ubyte format_byte;
}alias lv_table_cell_format_t = _Lv_table_cell_format_t;

/*Data of table*/
struct _Lv_table_ext_t {
    /*New data for this type */
    ushort col_cnt;
    ushort row_cnt;
    char** cell_data;
    const(lv_style_t)*[LV_TABLE_CELL_STYLE_CNT] cell_style;
    lv_coord_t[LV_TABLE_COL_MAX] col_w;
}alias lv_table_ext_t = _Lv_table_ext_t;

/*Styles*/
enum {
    LV_TABLE_STYLE_BG,
    LV_TABLE_STYLE_CELL1,
    LV_TABLE_STYLE_CELL2,
    LV_TABLE_STYLE_CELL3,
    LV_TABLE_STYLE_CELL4,
};
alias lv_table_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a table object
 * @param par pointer to an object, it will be the parent of the new table
 * @param copy pointer to a table object, if not NULL then the new object will be copied from it
 * @return pointer to the created table
 */
lv_obj_t* lv_table_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*=====================
 * Setter functions
 *====================*/

/**
 * Set the value of a cell.
 * @param table pointer to a Table object
 * @param row id of the row [0 .. row_cnt -1]
 * @param col id of the column [0 .. col_cnt -1]
 * @param txt text to display in the cell. It will be copied and saved so this variable is not
 * required after this function call.
 */
void lv_table_set_cell_value(lv_obj_t* table, ushort row, ushort col, const(char)* txt);

/**
 * Set the number of rows
 * @param table table pointer to a Table object
 * @param row_cnt number of rows
 */
void lv_table_set_row_cnt(lv_obj_t* table, ushort row_cnt);

/**
 * Set the number of columns
 * @param table table pointer to a Table object
 * @param col_cnt number of columns. Must be < LV_TABLE_COL_MAX
 */
void lv_table_set_col_cnt(lv_obj_t* table, ushort col_cnt);

/**
 * Set the width of a column
 * @param table table pointer to a Table object
 * @param col_id id of the column [0 .. LV_TABLE_COL_MAX -1]
 * @param w width of the column
 */
void lv_table_set_col_width(lv_obj_t* table, ushort col_id, lv_coord_t w);

/**
 * Set the text align in a cell
 * @param table pointer to a Table object
 * @param row id of the row [0 .. row_cnt -1]
 * @param col id of the column [0 .. col_cnt -1]
 * @param align LV_LABEL_ALIGN_LEFT or LV_LABEL_ALIGN_CENTER or LV_LABEL_ALIGN_RIGHT
 */
void lv_table_set_cell_align(lv_obj_t* table, ushort row, ushort col, lv_label_align_t align_);

/**
 * Set the type of a cell.
 * @param table pointer to a Table object
 * @param row id of the row [0 .. row_cnt -1]
 * @param col id of the column [0 .. col_cnt -1]
 * @param type 1,2,3 or 4. The cell style will be chosen accordingly.
 */
void lv_table_set_cell_type(lv_obj_t* table, ushort row, ushort col, ubyte type);

/**
 * Set the cell crop. (Don't adjust the height of the cell according to its content)
 * @param table pointer to a Table object
 * @param row id of the row [0 .. row_cnt -1]
 * @param col id of the column [0 .. col_cnt -1]
 * @param crop true: crop the cell content; false: set the cell height to the content.
 */
void lv_table_set_cell_crop(lv_obj_t* table, ushort row, ushort col, bool crop);

/**
 * Merge a cell with the right neighbor. The value of the cell to the right won't be displayed.
 * @param table table pointer to a Table object
 * @param row id of the row [0 .. row_cnt -1]
 * @param col id of the column [0 .. col_cnt -1]
 * @param en true: merge right; false: don't merge right
 */
void lv_table_set_cell_merge_right(lv_obj_t* table, ushort row, ushort col, bool en);

/**
 * Set a style of a table.
 * @param table pointer to table object
 * @param type which style should be set
 * @param style pointer to a style
 */
void lv_table_set_style(lv_obj_t* table, lv_table_style_t type, const(lv_style_t)* style);

/*=====================
 * Getter functions
 *====================*/

/**
 * Get the value of a cell.
 * @param table pointer to a Table object
 * @param row id of the row [0 .. row_cnt -1]
 * @param col id of the column [0 .. col_cnt -1]
 * @return text in the cell
 */
const(char)* lv_table_get_cell_value(lv_obj_t* table, ushort row, ushort col);

/**
 * Get the number of rows.
 * @param table table pointer to a Table object
 * @return number of rows.
 */
ushort lv_table_get_row_cnt(lv_obj_t* table);

/**
 * Get the number of columns.
 * @param table table pointer to a Table object
 * @return number of columns.
 */
ushort lv_table_get_col_cnt(lv_obj_t* table);

/**
 * Get the width of a column
 * @param table table pointer to a Table object
 * @param col_id id of the column [0 .. LV_TABLE_COL_MAX -1]
 * @return width of the column
 */
lv_coord_t lv_table_get_col_width(lv_obj_t* table, ushort col_id);

/**
 * Get the text align of a cell
 * @param table pointer to a Table object
 * @param row id of the row [0 .. row_cnt -1]
 * @param col id of the column [0 .. col_cnt -1]
 * @return LV_LABEL_ALIGN_LEFT (default in case of error) or LV_LABEL_ALIGN_CENTER or
 * LV_LABEL_ALIGN_RIGHT
 */
lv_label_align_t lv_table_get_cell_align(lv_obj_t* table, ushort row, ushort col);

/**
 * Get the type of a cell
 * @param table pointer to a Table object
 * @param row id of the row [0 .. row_cnt -1]
 * @param col id of the column [0 .. col_cnt -1]
 * @return 1,2,3 or 4
 */
lv_label_align_t lv_table_get_cell_type(lv_obj_t* table, ushort row, ushort col);

/**
 * Get the crop property of a cell
 * @param table pointer to a Table object
 * @param row id of the row [0 .. row_cnt -1]
 * @param col id of the column [0 .. col_cnt -1]
 * @return true: text crop enabled; false: disabled
 */
lv_label_align_t lv_table_get_cell_crop(lv_obj_t* table, ushort row, ushort col);

/**
 * Get the cell merge attribute.
 * @param table table pointer to a Table object
 * @param row id of the row [0 .. row_cnt -1]
 * @param col id of the column [0 .. col_cnt -1]
 * @return true: merge right; false: don't merge right
 */
bool lv_table_get_cell_merge_right(lv_obj_t* table, ushort row, ushort col);

/**
 * Get style of a table.
 * @param table pointer to table object
 * @param type which style should be get
 * @return style pointer to the style
 */
const(lv_style_t)* lv_table_get_style(const(lv_obj_t)* table, lv_table_style_t type);

/*=====================
 * Other functions
 *====================*/

/**********************
 *      MACROS
 **********************/

} /*LV_USE_TABLE*/

version (none) {}
} /* extern "C" */
}

 /*LV_TABLE_H*/
