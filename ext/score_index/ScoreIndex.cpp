// Copyright (c) 2018 Yegor Bugayenko
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the 'Software'), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include <array>
#include <condition_variable>
#include <future>
#include <iostream>
#include <mutex>
#include <random>
#include <sstream>
#include <thread>
#include <vector>
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
	const string chars =
		"0123456789"
		"abcdefghijklmnopqrstuvwxyz"
		"ABCDEFGHIJKLMNOPQRSTUVWXYZ";

	string rv;
	for (int l = 0; l < 6; l++) {	// Cut to 6 sym
		rv += chars[i % chars.size()];
		if (i < chars.size()) {
			break;
		}
		i /= chars.size();
	}
	return {rv.rbegin(), rv.rend()};
}

static atomic<bool> found;
static mutex mtx;
static condition_variable cv;
static string nonce;

static
void index_core(const string &prefix, int strength, uint64_t base)
{
	for (uint64_t i = base; ; i++) {
		if (found) {
			break;
		}
		const auto hash = sha256(prefix + " " + create_nonce(i));
		if (check_hash(hash, strength)) {
			unique_lock<mutex> lock(mtx);
			nonce = create_nonce(i);
			found = true;
			cv.notify_one();
		}
	}
}

static
string index(const string &prefix, int strength)
{
	mt19937_64 random(uint64_t(time(nullptr)));
	found = false;

	int cpus = std::thread::hardware_concurrency();
	vector<thread> threads;
	for (int i = 0; i < cpus; i++) {
		threads.emplace_back(index_core, prefix, strength, random());
	}

	unique_lock<mutex> lock(mtx);
	while (!found) {
		cv.wait(lock);
	}
	lock.unlock();

	for (auto &t : threads) {
		t.join();
	}

	return nonce;
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
