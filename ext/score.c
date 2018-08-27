#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <openssl/sha.h>

// This function converts the input data into SHA-256 hash
static unsigned char* sha256(unsigned char* hash, char* data) {
  size_t length = strlen((char*)data);
  SHA256((const unsigned char*)data, length, hash);
  return hash;
}

// Calculate nonce for strength x with a given data, offset and limit
uint64_t calculate_nonce_extended(uint64_t offset, uint64_t limit, char* data, uint8_t strength) {
  uint64_t nonce = offset;
  size_t data_length = strlen(data);
  char* current_data = malloc(data_length + 20);
  unsigned char* hash = malloc(SHA256_DIGEST_LENGTH);
  char* current_data_nonce = current_data + data_length;
  memcpy(current_data, data, data_length);
  while(1) {
    sprintf(current_data_nonce, "%lx", nonce);
    hash = sha256(hash, current_data);
    for(uint8_t i = 1; i <= strength / 2; i++) {
      if(hash[SHA256_DIGEST_LENGTH - i] != 0) {
        goto next_nonce_round;
      }
    }
    if(strength & 1
       && (hash[SHA256_DIGEST_LENGTH - (strength / 2) - 1] & 0x0f) != 0) {
      goto next_nonce_round;
    }
    break;
next_nonce_round:
    nonce++;
    if(!(nonce ^ limit)) {
      nonce = 0;
      break;
    }
  }
  free(hash);
  free(current_data);
  return nonce;
}
