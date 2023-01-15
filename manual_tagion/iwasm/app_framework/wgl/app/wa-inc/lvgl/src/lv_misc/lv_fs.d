module lv_fs;
@nogc nothrow:
extern(C): __gshared:
/**
 * @file lv_fs.h
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

static if (LV_USE_FILESYSTEM) {

public import core.stdc.stdint;
public import stdbool;
public import lv_mem;

/*********************
 *      DEFINES
 *********************/
enum LV_FS_MAX_FN_LENGTH = 64;

/**********************
 *      TYPEDEFS
 **********************/
/**
 * Errors in the filesystem module.
 */
enum {
    LV_FS_RES_OK = 0,
    LV_FS_RES_HW_ERR,     /*Low level hardware error*/
    LV_FS_RES_FS_ERR,     /*Error in the file system structure */
    LV_FS_RES_NOT_EX,     /*Driver, file or directory is not exists*/
    LV_FS_RES_FULL,       /*Disk full*/
    LV_FS_RES_LOCKED,     /*The file is already opened*/
    LV_FS_RES_DENIED,     /*Access denied. Check 'fs_open' modes and write protect*/
    LV_FS_RES_BUSY,       /*The file system now can't handle it, try later*/
    LV_FS_RES_TOUT,       /*Process time outed*/
    LV_FS_RES_NOT_IMP,    /*Requested function is not implemented*/
    LV_FS_RES_OUT_OF_MEM, /*Not enough memory for an internal operation*/
    LV_FS_RES_INV_PARAM,  /*Invalid parameter among arguments*/
    LV_FS_RES_UNKNOWN,    /*Other unknown error*/
};
alias lv_fs_res_t = ubyte;

/**
 * Filesystem mode.
 */
enum {
    LV_FS_MODE_WR = 0x01,
    LV_FS_MODE_RD = 0x02,
};
alias lv_fs_mode_t = ubyte;

struct _lv_fs_drv_t {
    char letter = 0;
    ushort file_size;
    ushort rddir_size;
    bool function(_lv_fs_drv_t* drv) ready_cb;

    lv_fs_res_t function(_lv_fs_drv_t* drv, void* file_p, const(char)* path, lv_fs_mode_t mode) open_cb;
    lv_fs_res_t function(_lv_fs_drv_t* drv, void* file_p) close_cb;
    lv_fs_res_t function(_lv_fs_drv_t* drv, const(char)* fn) remove_cb;
    lv_fs_res_t function(_lv_fs_drv_t* drv, void* file_p, void* buf, uint btr, uint* br) read_cb;
    lv_fs_res_t function(_lv_fs_drv_t* drv, void* file_p, const(void)* buf, uint btw, uint* bw) write_cb;
    lv_fs_res_t function(_lv_fs_drv_t* drv, void* file_p, uint pos) seek_cb;
    lv_fs_res_t function(_lv_fs_drv_t* drv, void* file_p, uint* pos_p) tell_cb;
    lv_fs_res_t function(_lv_fs_drv_t* drv, void* file_p) trunc_cb;
    lv_fs_res_t function(_lv_fs_drv_t* drv, void* file_p, uint* size_p) size_cb;
    lv_fs_res_t function(_lv_fs_drv_t* drv, const(char)* oldname, const(char)* newname) rename_cb;
    lv_fs_res_t function(_lv_fs_drv_t* drv, uint* total_p, uint* free_p) free_space_cb;

    lv_fs_res_t function(_lv_fs_drv_t* drv, void* rddir_p, const(char)* path) dir_open_cb;
    lv_fs_res_t function(_lv_fs_drv_t* drv, void* rddir_p, char* fn) dir_read_cb;
    lv_fs_res_t function(_lv_fs_drv_t* drv, void* rddir_p) dir_close_cb;

static if (LV_USE_USER_DATA) {
    lv_fs_drv_user_data_t user_data; /**< Custom file user data */
}
}alias lv_fs_drv_t = _lv_fs_drv_t;

struct _Lv_fs_file_t {
    void* file_d;
    lv_fs_drv_t* drv;
}alias lv_fs_file_t = _Lv_fs_file_t;

struct _Lv_fs_dir_t {
    void* dir_d;
    lv_fs_drv_t* drv;
}alias lv_fs_dir_t = _Lv_fs_dir_t;

/**********************
 * GLOBAL PROTOTYPES
 **********************/

/**
 * Initialize the File system interface
 */
void lv_fs_init();

/**
 * Initialize a file system driver with default values.
 * It is used to surly have known values in the fields ant not memory junk.
 * After it you can set the fields.
 * @param drv pointer to driver variable to initialize
 */
void lv_fs_drv_init(lv_fs_drv_t* drv);

/**
 * Add a new drive
 * @param drv_p pointer to an lv_fs_drv_t structure which is inited with the
 * corresponding function pointers. The data will be copied so the variable can be local.
 */
void lv_fs_drv_register(lv_fs_drv_t* drv_p);

/**
 * Give a pointer to a driver from its letter
 * @param letter the driver letter
 * @return pointer to a driver or NULL if not found
 */
lv_fs_drv_t* lv_fs_get_drv(char letter);

/**
 * Test if a drive is rady or not. If the `ready` function was not initialized `true` will be
 * returned.
 * @param letter letter of the drive
 * @return true: drive is ready; false: drive is not ready
 */
bool lv_fs_is_ready(char letter);

/**
 * Open a file
 * @param file_p pointer to a lv_fs_file_t variable
 * @param path path to the file beginning with the driver letter (e.g. S:/folder/file.txt)
 * @param mode read: FS_MODE_RD, write: FS_MODE_WR, both: FS_MODE_RD | FS_MODE_WR
 * @return LV_FS_RES_OK or any error from lv_fs_res_t enum
 */
lv_fs_res_t lv_fs_open(lv_fs_file_t* file_p, const(char)* path, lv_fs_mode_t mode);

/**
 * Close an already opened file
 * @param file_p pointer to a lv_fs_file_t variable
 * @return  LV_FS_RES_OK or any error from lv_fs_res_t enum
 */
lv_fs_res_t lv_fs_close(lv_fs_file_t* file_p);

/**
 * Delete a file
 * @param path path of the file to delete
 * @return  LV_FS_RES_OK or any error from lv_fs_res_t enum
 */
lv_fs_res_t lv_fs_remove(const(char)* path);

/**
 * Read from a file
 * @param file_p pointer to a lv_fs_file_t variable
 * @param buf pointer to a buffer where the read bytes are stored
 * @param btr Bytes To Read
 * @param br the number of real read bytes (Bytes Read). NULL if unused.
 * @return LV_FS_RES_OK or any error from lv_fs_res_t enum
 */
lv_fs_res_t lv_fs_read(lv_fs_file_t* file_p, void* buf, uint btr, uint* br);

/**
 * Write into a file
 * @param file_p pointer to a lv_fs_file_t variable
 * @param buf pointer to a buffer with the bytes to write
 * @param btr Bytes To Write
 * @param br the number of real written bytes (Bytes Written). NULL if unused.
 * @return LV_FS_RES_OK or any error from lv_fs_res_t enum
 */
lv_fs_res_t lv_fs_write(lv_fs_file_t* file_p, const(void)* buf, uint btw, uint* bw);

/**
 * Set the position of the 'cursor' (read write pointer) in a file
 * @param file_p pointer to a lv_fs_file_t variable
 * @param pos the new position expressed in bytes index (0: start of file)
 * @return LV_FS_RES_OK or any error from lv_fs_res_t enum
 */
lv_fs_res_t lv_fs_seek(lv_fs_file_t* file_p, uint pos);

/**
 * Give the position of the read write pointer
 * @param file_p pointer to a lv_fs_file_t variable
 * @param pos_p pointer to store the position of the read write pointer
 * @return LV_FS_RES_OK or any error from 'fs_res_t'
 */
lv_fs_res_t lv_fs_tell(lv_fs_file_t* file_p, uint* pos);

/**
 * Truncate the file size to the current position of the read write pointer
 * @param file_p pointer to an 'ufs_file_t' variable. (opened with lv_fs_open )
 * @return LV_FS_RES_OK: no error, the file is read
 *         any error from lv_fs_res_t enum
 */
lv_fs_res_t lv_fs_trunc(lv_fs_file_t* file_p);

/**
 * Give the size of a file bytes
 * @param file_p pointer to a lv_fs_file_t variable
 * @param size pointer to a variable to store the size
 * @return LV_FS_RES_OK or any error from lv_fs_res_t enum
 */
lv_fs_res_t lv_fs_size(lv_fs_file_t* file_p, uint* size);

/**
 * Rename a file
 * @param oldname path to the file
 * @param newname path with the new name
 * @return LV_FS_RES_OK or any error from 'fs_res_t'
 */
lv_fs_res_t lv_fs_rename(const(char)* oldname, const(char)* newname);

/**
 * Initialize a 'fs_dir_t' variable for directory reading
 * @param rddir_p pointer to a 'fs_read_dir_t' variable
 * @param path path to a directory
 * @return LV_FS_RES_OK or any error from lv_fs_res_t enum
 */
lv_fs_res_t lv_fs_dir_open(lv_fs_dir_t* rddir_p, const(char)* path);

/**
 * Read the next filename form a directory.
 * The name of the directories will begin with '/'
 * @param rddir_p pointer to an initialized 'fs_rdir_t' variable
 * @param fn pointer to a buffer to store the filename
 * @return LV_FS_RES_OK or any error from lv_fs_res_t enum
 */
lv_fs_res_t lv_fs_dir_read(lv_fs_dir_t* rddir_p, char* fn);

/**
 * Close the directory reading
 * @param rddir_p pointer to an initialized 'fs_dir_t' variable
 * @return LV_FS_RES_OK or any error from lv_fs_res_t enum
 */
lv_fs_res_t lv_fs_dir_close(lv_fs_dir_t* rddir_p);

/**
 * Get the free and total size of a driver in kB
 * @param letter the driver letter
 * @param total_p pointer to store the total size [kB]
 * @param free_p pointer to store the free size [kB]
 * @return LV_FS_RES_OK or any error from lv_fs_res_t enum
 */
lv_fs_res_t lv_fs_free_space(char letter, uint* total_p, uint* free_p);

/**
 * Fill a buffer with the letters of existing drivers
 * @param buf buffer to store the letters ('\0' added after the last letter)
 * @return the buffer
 */
char* lv_fs_get_letters(char* buf);

/**
 * Return with the extension of the filename
 * @param fn string with a filename
 * @return pointer to the beginning extension or empty string if no extension
 */
const(char)* lv_fs_get_ext(const(char)* fn);

/**
 * Step up one level
 * @param path pointer to a file name
 * @return the truncated file name
 */
char* lv_fs_up(char* path);

/**
 * Get the last element of a path (e.g. U:/folder/file -> file)
 * @param buf buffer to store the letters ('\0' added after the last letter)
 * @return pointer to the beginning of the last element in the path
 */
const(char)* lv_fs_get_last(const(char)* path);

/**********************
 *      MACROS
 **********************/

} /*LV_USE_FILESYSTEM*/

version (none) {}
} /* extern "C" */
}

 /*LV_FS_H*/
