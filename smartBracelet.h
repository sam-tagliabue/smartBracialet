#ifndef SMARTBRACELET_H
#define SMARTBRACELET_H

#define K_LEN 20

// Message struct
typedef nx_struct sb_msg {
  	nx_uint8_t msg_type;
  	nx_uint16_t msg_id;

  	nx_uint8_t data[21];
  	nx_uint16_t X;
  	nx_uint16_t Y;
  	nx_uint8_t status;
} sb_msg_t;

typedef struct sensorStatus {
  uint8_t status;
  uint16_t X;
  uint16_t Y;
} sensor_status;


// Constants
enum {
  AM_RADIO_TYPE = 6,
};

static const char KEY[8][20]={{"BD2d3VsBNIsfJO68dIby"},
{"BFBD2d3VsBNIsfJO68dI"},
{"xr3gBthvdhvFhvB6iHUH"},
{"ygxbbBb7UUYUYGiubiuh"},
{"sacuycagb7Nun0u90m9I"},
{"IMIMi09i9ioinhbvdc5c"},
{"q65v76tb8n98u09mu9n8"},
{"nuyb8byn98uiyi8u9uBF"}};
#endif

