/* audiotap: counts audio dropouts in a Wine game (skyrim-together.sh with ST_AUDIO_DIAG=1 injects it).
 * Derived from SkyrimMT's tools/audiotap/audiotap.c (MIT). Wraps the render callback Wine's winecoreaudio gives each
 * output AudioUnit; after Wine fills a buffer, a run of exact zeros at its END following real sound is padding Wine
 * added because the game had not queued enough audio: a dropout, heard as a click or crackle. Buffers that are all
 * zeros are counted apart (silence in the game, or a longer stall: they can't be told apart here).
 *   AUDIOTAP_LOG=<file>   per-stream totals rewritten every 2 s to <file>.<pid>
 * Build (x86_64, Wine runs under Rosetta):
 *   clang -arch x86_64 -dynamiclib -O2 launch/audiotap.c -o ~/Games/skyrim/tools/audiotap.dylib -framework AudioUnit */
#include <AudioUnit/AudioUnit.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define DYLD_INTERPOSE(_r, _o) __attribute__((used)) static struct { const void *r; const void *o; } _interpose_##_o \
    __attribute__((section("__DATA,__interpose"))) = { (const void *)(unsigned long)&_r, (const void *)(unsigned long)&_o };

enum { kMaxStreams = 8, kMinPaddedFrames = 16 };   /* shorter zero runs occur in real sound */

typedef struct {
    AURenderCallback cb; void *ref; Float64 rate; UInt32 channels;
    volatile long calls, frames_per_call, dropouts, padded_frames, silent_calls;
} Stream;
static Stream streams[kMaxStreams];
static volatile int nstreams;

static UInt32 trailing_zero_frames(const AudioBuffer *b, UInt32 frames) {
    const float *s = b->mData; UInt32 ch = b->mNumberChannels ? b->mNumberChannels : 1, z = 0;
    while (z < frames) {
        const float *f = s + (size_t)(frames - 1 - z) * ch; UInt32 c = 0;
        while (c < ch && f[c] == 0.0f) c++;
        if (c < ch) break;
        z++;
    }
    return z;
}

static OSStatus tap_render(void *ref, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *ts, UInt32 bus, UInt32 n, AudioBufferList *data) {
    Stream *t = ref;
    OSStatus r = t->cb(t->ref, flags, ts, bus, n, data);
    /* Wine renders 32-bit float (its AudioUnit format); anything else is not inspected */
    if (data && data->mNumberBuffers >= 1 && data->mBuffers[0].mData) {
        const AudioBuffer *b = &data->mBuffers[0];
        UInt32 ch = b->mNumberChannels ? b->mNumberChannels : 1, frames = b->mDataByteSize / (4 * ch);
        UInt32 z = trailing_zero_frames(b, frames);
        if (z == frames) t->silent_calls++;
        else if (z >= kMinPaddedFrames) { t->dropouts++; t->padded_frames += z; }
    }
    t->calls++; t->frames_per_call = n;
    return r;
}

static OSStatus tap_set_property(AudioUnit u, AudioUnitPropertyID id, AudioUnitScope sc, AudioUnitElement el, const void *data, UInt32 size) {
    if (id != kAudioUnitProperty_SetRenderCallback || !data || nstreams >= kMaxStreams)
        return AudioUnitSetProperty(u, id, sc, el, data, size);
    const AURenderCallbackStruct *in = data;
    Stream *t = &streams[nstreams];
    t->cb = in->inputProc; t->ref = in->inputProcRefCon;
    AudioStreamBasicDescription d; UInt32 dsz = sizeof d;
    if (AudioUnitGetProperty(u, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &d, &dsz) == noErr) {
        t->rate = d.mSampleRate; t->channels = d.mChannelsPerFrame;
    }
    nstreams++;
    AURenderCallbackStruct mine = { tap_render, t };
    return AudioUnitSetProperty(u, id, sc, el, &mine, sizeof mine);
}
DYLD_INTERPOSE(tap_set_property, AudioUnitSetProperty)

static void *writer(void *path) {
    char fn[1024]; snprintf(fn, sizeof fn, "%s.%d", (const char *)path, getpid());
    for (;;) {
        sleep(2);
        if (!nstreams) continue;   /* only processes that play audio write (Wine starts several) */
        FILE *f = fopen(fn, "w");
        if (!f) { fprintf(stderr, "audiotap: cannot write %s\n", fn); return NULL; }
        for (int i = 0; i < nstreams; i++) {
            const Stream *t = &streams[i];
            fprintf(f, "stream%d rate=%.0f ch=%u calls=%ld frames_per_call=%ld dropouts=%ld padded_frames=%ld silent_calls=%ld\n",
                    i, t->rate, t->channels, t->calls, t->frames_per_call, t->dropouts, t->padded_frames, t->silent_calls);
        }
        fclose(f);
    }
}

__attribute__((constructor)) static void init(void) {
    const char *log = getenv("AUDIOTAP_LOG");
    pthread_t th;
    if (log && pthread_create(&th, NULL, writer, (void *)log) == 0) pthread_detach(th);
}
