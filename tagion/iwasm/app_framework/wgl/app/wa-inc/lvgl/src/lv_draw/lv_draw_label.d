module lv_draw_label;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_draw_label.h
 *
 */

 
version (none) {
extern "C" {
//! #endif

/*********************
 *      INCLUDES
 *********************/
public import lv_draw;

/*********************
 *      DEFINES
 *********************/

/**********************
 *      TYPEDEFS
 **********************/

/** Store some info to speed up drawing of very large texts
 * It takes a lot of time to get the first visible character because
 * all the previous characters needs to be checked to calculate the positions.
 * This structure stores an earlier (e.g. at -1000 px) coordinate and the index of that line.
 * Therefore the calculations can start from here.*/
struct _Lv_draw_label_hint_t {
    /** Index of the line at `y` coordinate*/
    int line_start;

    /** Give the `y` coordinate of the first letter at `line start` index. Relative to the label's coordinates*/
    int y;

    /** The 'y1' coordinate of the label when the hint was saved.
     * Used to invalidate the hint if the label has moved too much. */
    int coord_y;
}alias lv_draw_label_hint_t = _Lv_draw_label_hint_t;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Write a text
 * @param coords coordinates of the label
 * @param mask the label will be drawn only in this area
 * @param style pointer to a style
 * @param opa_scale scale down all opacities by the factor
 * @param txt 0 terminated text to write
 * @param flag settings for the text from 'txt_flag_t' enum
 * @param offset text offset in x and y direction (NULL if unused)
 * @param sel_start start index of selected area (`LV_LABEL_TXT_SEL_OFF` if none)
 * @param sel_end end index of selected area (`LV_LABEL_TXT_SEL_OFF` if none)
 */
void lv_draw_label(const(lv_area_t)* coords, const(lv_area_t)* mask, const(lv_style_t)* style, lv_opa_t opa_scale, const(char)* txt, lv_txt_flag_t flag, lv_point_t* offset, ushort sel_start, ushort sel_end, lv_draw_label_hint_t* hint);

/**********************
 *      MACROS
 **********************/

version (none) {}
} /* extern "C" */
}

 /*LV_DRAW_LABEL_H*/
