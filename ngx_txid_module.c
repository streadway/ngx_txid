#include <nginx.h>
#include <ngx_http.h>
#include <ngx_http_variables.h>

void   ngx_txid_base32_encode(unsigned char *dst, unsigned char *src, size_t n);
size_t ngx_txid_base32_encode_len(size_t n);

static int          txid_dev_urandom = 0;
static ngx_msec_t   txid_last_msec = 0;

// returns monotonically increasing msec per process based on the msec
// variable incrementing at `timer_resolution` intervals.  The amount of
// relevant entropy should cover the global requests per msec rate
ngx_msec_t
ngx_txid_next_tick() {
    if (ngx_current_msec > txid_last_msec) {
        txid_last_msec = ngx_current_msec;
    }

    return txid_last_msec;
}

// reads len bytes from the urandom dev into *buf, returns the
// number of bytes of entropy bytes read
size_t
ngx_txid_get_entropy(unsigned char *buf, const size_t len) {
    size_t i = 0;
    size_t n = len;
    u_char *p = buf;
    int retries = 32;

    while (n > 0 && retries > 0) {
        i = read(txid_dev_urandom, (void*)p, n);

        // reading from urandom shouldn't ever block or be interrupted or
        // return less than the requested bytes.
        if (i <= 0) {
            retries--;
            continue;
        }

        p += i;
        n -= i;
    }

    return len - n;
}

// makes a roughly sortable identifier in at least 96 bytes.
// +-------------64bit BE-----------remaining > 32 bits---+
// | 42 bits msec | 22 bits rand | random...
// +------------------------------------------------------+
// returns <0 on failure
int
ngx_txid_make(unsigned char *out, const size_t len) {
    if (len < 12) {
        // not enough entropy to avoid collisions
        return -1;
    }

    const size_t n = ngx_txid_get_entropy(out, len);
    if (n < len) {
        // not enough entropy in system
        return -1;
    }

    // The timestamp is 64 bits, but shorten it to 42 bits. This is enough to
    // store dates up to 2109-05-15 (4398046511103 milliseconds past epoch).
    const ngx_msec_t msec = ngx_txid_next_tick() << 22;
    out[0] =  (msec >> (64 - 1 * 8)) & 0xff; // 1st byte - bits 1-8 of time
    out[1] =  (msec >> (64 - 2 * 8)) & 0xff; // 2nd byte - bits 9-16 of time
    out[2] =  (msec >> (64 - 3 * 8)) & 0xff; // 3rd byte - bits 17-24 of time
    out[3] =  (msec >> (64 - 4 * 8)) & 0xff; // 4th byte - bits 25-32 of time
    out[4] =  (msec >> (64 - 5 * 8)) & 0xff; // 5th byte - bits 32-40 of time
    out[5] |= (msec >> (64 - 6 * 8)) & 0xff; // 6th byte - bits 41-42 of time
                                             // the rest of the byte is shared
                                             // with entropy

    return 0;
}

static ngx_int_t
ngx_txid_get(ngx_http_request_t *r, ngx_http_variable_value_t *v, uintptr_t data) {
    const size_t bits = 96;
    const size_t len  = (bits+7)/8;

    u_char rnd[len];

    if (ngx_txid_make(rnd, len) < 0) {
        ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                      "not enough entropy (want %d bytes) for \"$txid\"", len);
        v->valid = 0;
        v->not_found = 1;
        return NGX_ERROR;
    }

    size_t enclen = ngx_txid_base32_encode_len(len);

    u_char *out = ngx_pnalloc(r->pool, enclen);
    if (out == NULL) {
        v->valid = 0;
        v->not_found = 1;
        return NGX_ERROR;
    }

    ngx_txid_base32_encode(out, rnd, len);

    v->len = (bits+4)/5; // strip any padding chars
    v->data = out;

    v->valid = 1;
    v->not_found = 0;
    v->no_cacheable = 0;

    return NGX_OK;
}

static ngx_int_t
ngx_txid_init_module(ngx_cycle_t *cycle) {
    txid_dev_urandom = open("/dev/urandom", O_RDONLY | O_CLOEXEC);
    if (txid_dev_urandom == -1) {
        ngx_log_error(NGX_LOG_ERR, cycle->log, 0,
                      "could not open /dev/urandom device for \"$txid\"");
        return NGX_ERROR;
    }

    ngx_log_error(NGX_LOG_DEBUG, cycle->log, 0,
                  "opened /dev/urandom %d for pid %d", txid_dev_urandom, ngx_pid);

    return NGX_OK;
}

static ngx_str_t ngx_txid_variable_name = ngx_string("txid");

static ngx_int_t ngx_txid_add_variables(ngx_conf_t *cf)
{
  ngx_http_variable_t* var = ngx_http_add_variable(
          cf,
          &ngx_txid_variable_name,
          NGX_HTTP_VAR_NOHASH);

  if (var == NULL) {
      return NGX_ERROR;
  }

  var->get_handler = ngx_txid_get;

  return NGX_OK;
}

static ngx_http_module_t  ngx_txid_module_ctx = {
  ngx_txid_add_variables,     /* preconfiguration */
  NULL,                        /* postconfiguration */

  NULL,        /* create main configuration */
  NULL,        /* init main configuration */

  NULL,        /* create server configuration */
  NULL,        /* merge server configuration */

  NULL,        /* create location configuration */
  NULL         /* merge location configuration */
};

static ngx_command_t  ngx_txid_module_commands[] = {
  ngx_null_command
};

ngx_module_t  ngx_txid_module = {
  NGX_MODULE_V1,
  &ngx_txid_module_ctx,      /* module context */
  ngx_txid_module_commands,  /* module directives */
  NGX_HTTP_MODULE,                /* module type */
  NULL,                           /* init master */
  ngx_txid_init_module,           /* init module */
  NULL,                           /* init process */
  NULL,                           /* init thread */
  NULL,                           /* exit thread */
  NULL,                           /* exit process */
  NULL,                           /* exit master */
  NGX_MODULE_V1_PADDING
};

