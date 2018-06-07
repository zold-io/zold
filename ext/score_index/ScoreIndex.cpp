// Copyright (c) 2018 Yegor Bugayenko
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the 'Software'), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include <array>
#include <sstream>
#include <openssl/sha.h>
#include <ruby.h>

using namespace std;

static
array<uint8_t, SHA256_DIGEST_LENGTH> sha256(const string &string)
{
	SHA256_CTX ctx;
	SHA256_Init(&ctx);
	SHA256_Update(&ctx, string.data(), string.size());
	array<uint8_t, SHA256_DIGEST_LENGTH> hash;
	SHA256_Final(&hash[0], &ctx);
	return hash;
}

static
bool check_hash(const array<uint8_t, SHA256_DIGEST_LENGTH> &hash, int strength)
{
	int current_strength = 0;
	const auto rend = hash.rend();
	for (auto h = hash.rbegin(); h != rend; ++h) {
		if ((*h & 0x0f) != 0) {
			break;
		}
		current_strength += (*h == 0) ? 2 : 1;
		if (*h != 0) {
			break;
		}
	}
	return current_strength >= strength;
}

static
string create_nonce(uint64_t i)
{
	ostringstream out;
	out << hex << i;
	return out.str();
}

static
string index(const string &prefix, int strength)
{
	for (uint64_t i = 0; ; i++) {
		const auto nonce = create_nonce(i);
		const auto hash = sha256(prefix + " " + nonce);
		if (check_hash(hash, strength)) {
			return nonce;
		}
	}
	return {};
}

static
VALUE ScoreIndex_initialize(VALUE self, VALUE prefix, VALUE strength)
{
	rb_iv_set(self, "@prefix", prefix);
	rb_iv_set(self, "@strength", strength);
	return self;
}

static
VALUE ScoreIndex_value(VALUE self)
{
	auto prefix_value = rb_iv_get(self, "@prefix");
	const string prefix = StringValuePtr(prefix_value);
	const int strength = NUM2INT(rb_iv_get(self, "@strength"));
	const auto nonce = index(prefix, strength);
	return rb_str_new2(nonce.c_str());
}

extern "C"
void Init_score_index()
{
	VALUE module = rb_define_module("Zold");
	VALUE score_index = rb_define_class_under(
		module,
		"ScoreIndex",
		rb_cObject
	);
	rb_define_method(
		score_index,
		"initialize",
		reinterpret_cast<VALUE(*)(...)>(ScoreIndex_initialize),
		2
	);
	rb_define_method(
		score_index,
		"value",
		reinterpret_cast<VALUE(*)(...)>(ScoreIndex_value),
		0
	);
}
