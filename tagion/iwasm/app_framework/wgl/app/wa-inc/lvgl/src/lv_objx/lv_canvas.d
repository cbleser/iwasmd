module lv_canvas;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_canvas.h
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

static if (LV_USE_CANVAS != 0) {

public import ...lv_core.lv_obj;
public import ...lv_objx.lv_img;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/
/*Data of canvas*/
struct _Lv_canvas_ext_t {
    lv_img_ext_t img; /*Ext. of ancestor*/
    /*New data for this type */
    lv_img_dsc_t dsc;
}alias lv_canvas_ext_t = _Lv_canvas_ext_t;

/*Styles*/
enum {
    LV_CANVAS_STYLE_MAIN,
};
alias lv_canvas_style_t = ubyte;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Create a canvas object
 * @param par pointer to an object, it will be the parent of the new canvas
 * @param copy pointer to a canvas object, if not NULL then the new object will be copied from it
 * @return pointer to the created canvas
 */
lv_obj_t* lv_canvas_create(lv_obj_t* par, const(lv_obj_t)* copy);

/*=====================
 * Setter functions
 *====================*/

/**
 * Set a buffer for the canvas.
 * @param buf a buffer where the content of the canvas will be.
 * The required size is (lv_img_color_format_get_px_size(cf) * w * h) / 8)
 * It can be allocated with `lv_mem_alloc()` or
 * it can be statically allocated array (e.g. static lv_color_t buf[100*50]) or
 * it can be an address in RAM or external SRAM
 * @param canvas pointer to a canvas object
 * @param w width of the canvas
 * @param h height of the canvas
 * @param cf color format. `LV_IMG_CF_...`
 */
void lv_canvas_set_buffer(lv_obj_t* canvas, void* buf, lv_coord_t w, lv_coord_t h, lv_img_cf_t cf);

/**
 * Set the color of a pixel on the canvas
 * @param canvas
 * @param x x coordinate of the point to set
 * @param y x coordinate of the point to set
 * @param c color of the point
 */
void lv_canvas_set_px(lv_obj_t* canvas, lv_coord_t x, lv_coord_t y, lv_color_t c);

/**
 * Set the palette color of a canvas with index format. Valid only for `LV_IMG_CF_INDEXED1/2/4/8`
 * @param canvas pointer to canvas object
 * @param id the palette color to set:
 *   - for `LV_IMG_CF_INDEXED1`: 0..1
 *   - for `LV_IMG_CF_INDEXED2`: 0..3
 *   - for `LV_IMG_CF_INDEXED4`: 0..15
 *   - for `LV_IMG_CF_INDEXED8`: 0..255
 * @param c the color to set
 */
void lv_canvas_set_palette(lv_obj_t* canvas, ubyte id, lv_color_t c);

/**
 * Set a style of a canvas.
 * @param canvas pointer to canvas object
 * @param type which style should be set
 * @param style pointer to a style
 */
void lv_canvas_set_style(lv_obj_t* canvas, lv_canvas_style_t type, const(lv_style_t)* style);

/*=====================
 * Getter functions
 *====================*/

/**
 * Get the color of a pixel on the canvas
 * @param canvas
 * @param x x coordinate of the point to set
 * @param y x coordinate of the point to set
 * @return color of the point
 */
lv_color_t lv_canvas_get_px(lv_obj_t* canvas, lv_coord_t x, lv_coord_t y);

/**
 * Get the image of the canvas as a pointer to an `lv_img_dsc_t` variable.
 * @param canvas pointer to a canvas object
 * @return pointer to the image descriptor.
 */
lv_img_dsc_t* lv_canvas_get_img(lv_obj_t* canvas);

/**
 * Get style of a canvas.
 * @param canvas pointer to canvas object
 * @param type which style should be get
 * @return style pointer to the style
 */
const(lv_style_t)* lv_canvas_get_style(const(lv_obj_t)* canvas, lv_canvas_style_t type);

/*=====================
 * Other functions
 *====================*/

/**
 * Copy a buffer to the canvas
 * @param canvas pointer to a canvas object
 * @param to_copy buffer to copy. The color format has to match with the canvas's buffer color
 * format
 * @param x left side of the destination position
 * @param y top side of the destination position
 * @param w width of the buffer to copy
 * @param h height of the buffer to copy
 */
void lv_canvas_copy_buf(lv_obj_t* canvas, const(void)* to_copy, lv_coord_t x, lv_coord_t y, lv_coord_t w, lv_coord_t h);

/**
 * Rotate and image and store the result on a canvas.
 * @param canvas pointer to a canvas object
 * @param img pointer to an image descriptor.
 *             Can be the image descriptor of an other canvas too (`lv_canvas_get_img()`).
 * @param angle the angle of rotation (0..360);
 * @param offset_x offset X to tell where to put the result data on destination canvas
 * @param offset_y offset X to tell where to put the result data on destination canvas
 * @param pivot_x pivot X of rotation. Relative to the source canvas
 *                Set to `source width / 2` to rotate around the center
 * @param pivot_y pivot Y of rotation. Relative to the source canvas
 *                Set to `source height / 2` to rotate around the center
 */
void lv_canvas_rotate(lv_obj_t* canvas, lv_img_dsc_t* img, short angle, lv_coord_t offset_x, lv_coord_t offset_y, int pivot_x, int pivot_y);

/**
 * Fill the canvas with color
 * @param canvas pointer to a canvas
 * @param color the background color
 */
void lv_canvas_fill_bg(lv_obj_t* canvas, lv_color_t color);

/**
 * Draw a rectangle on the canvas
 * @param canvas pointer to a canvas object
 * @param x left coordinate of the rectangle
 * @param y top coordinate of the rectangle
 * @param w width of the rectangle
 * @param h height of the rectangle
 * @param style style of the rectangle (`body` properties are used except `padding`)
 */
void lv_canvas_draw_rect(lv_obj_t* canvas, lv_coord_t x, lv_coord_t y, lv_coord_t w, lv_coord_t h, const(lv_style_t)* style);

/**
 * Draw a text on the canvas.
 * @param canvas pointer to a canvas object
 * @param x left coordinate of the text
 * @param y top coordinate of the text
 * @param max_w max width of the text. The text will be wrapped to fit into this size
 * @param style style of the text (`text` properties are used)
 * @param txt text to display
 * @param align align of the text (`LV_LABEL_ALIGN_LEFT/RIGHT/CENTER`)
 */
void lv_canvas_draw_text(lv_obj_t* canvas, lv_coord_t x, lv_coord_t y, lv_coord_t max_w, const(lv_style_t)* style, const(char)* txt, lv_label_align_t align_);

/**
 * Draw an image on the canvas
 * @param canvas pointer to a canvas object
 * @param src image source. Can be a pointer an `lv_img_dsc_t` variable or a path an image.
 * @param style style of the image (`image` properties are used)
 */
void lv_canvas_draw_img(lv_obj_t* canvas, lv_coord_t x, lv_coord_t y, const(void)* src, const(lv_style_t)* style);

/**
 * Draw a line on the canvas
 * @param canvas pointer to a canvas object
 * @param points point of the line
 * @param point_cnt number of points
 * @param style style of the line (`line` properties are used)
 */
void lv_canvas_draw_line(lv_obj_t* canvas, const(lv_point_t)* points, uint point_cnt, const(lv_style_t)* style);

/**
 * Draw a polygon on the canvas
 * @param canvas pointer to a canvas object
 * @param points point of the polygon
 * @param point_cnt number of points
 * @param style style of the polygon (`body.main_color` and `body.opa` is used)
 */
void lv_canvas_draw_polygon(lv_obj_t* canvas, const(lv_point_t)* points, uint point_cnt, const(lv_style_t)* style);

/**
 * Draw an arc on the canvas
 * @param canvas pointer to a canvas object
 * @param x origo x  of the arc
 * @param y origo y of the arc
 * @param r radius of the arc
 * @param start_angle start angle in degrees
 * @param end_angle end angle in degrees
 * @param style style of the polygon (`body.main_color` and `body.opa` is used)
 */
void lv_canvas_draw_arc(lv_obj_t* canvas, lv_coord_t x, lv_coord_t y, lv_coord_t r, int start_angle, int end_angle, const(lv_style_t)* style);

/**********************
 *      MACROS
 **********************/
enum string LV_CANVAS_BUF_SIZE_TRUE_COLOR(string w, string h) = ` ((LV_COLOR_SIZE / 8) * w * h)`;
enum string LV_CANVAS_BUF_SIZE_TRUE_COLOR_CHROMA_KEYED(string w, string h) = ` ((LV_COLOR_SIZE / 8) * w * h)`;
enum string LV_CANVAS_BUF_SIZE_TRUE_COLOR_ALPHA(string w, string h) = ` (LV_IMG_PX_SIZE_ALPHA_BYTE * w * h)`;

/*+ 1: to be sure no fractional row*/
enum string LV_CANVAS_BUF_SIZE_ALPHA_1BIT(string w, string h) = ` ((((w / 8) + 1) * h))`;
enum string LV_CANVAS_BUF_SIZE_ALPHA_2BIT(string w, string h) = ` ((((w / 4) + 1) * h))`;
enum string LV_CANVAS_BUF_SIZE_ALPHA_4BIT(string w, string h) = ` ((((w / 2) + 1) * h))`;
enum string LV_CANVAS_BUF_SIZE_ALPHA_8BIT(string w, string h) = ` ((w * h))`;

/*4 * X: for palette*/
enum string LV_CANVAS_BUF_SIZE_INDEXED_1BIT(string w, string h) = ` (LV_CANVAS_BUF_SIZE_ALPHA_1BIT(w, h) + 4 * 2)`;
enum string LV_CANVAS_BUF_SIZE_INDEXED_2BIT(string w, string h) = ` (LV_CANVAS_BUF_SIZE_ALPHA_2BIT(w, h) + 4 * 4)`;
enum string LV_CANVAS_BUF_SIZE_INDEXED_4BIT(string w, string h) = ` (LV_CANVAS_BUF_SIZE_ALPHA_4BIT(w, h) + 4 * 16)`;
enum string LV_CANVAS_BUF_SIZE_INDEXED_8BIT(string w, string h) = ` (LV_CANVAS_BUF_SIZE_ALPHA_8BIT(w, h) + 4 * 256)`;

} /*LV_USE_CANVAS*/

version (none) {}
} /* extern "C" */
}

 /*LV_CANVAS_H*/
