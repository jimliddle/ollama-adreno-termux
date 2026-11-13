# Troubleshooting

## Ollama still reports CPU use

Check the path first:

```sh
command -v ollama
```

It should end in `.local/bin/ollama`. If it points to Termux's `usr/bin`, run:

```sh
export PATH="$HOME/.local/bin:$PATH"
hash -r
```

An existing server keeps the settings it started with. Stop it through the
terminal or app that launched it, then start `ollama serve` again. A launcher
that uses the absolute path `$PREFIX/bin/ollama` bypasses this setup.

If the server log says it is dropping an integrated GPU, check that
`OLLAMA_IGPU_ENABLE` is set to `1` in the server's environment. An exported
value of `0` overrides this repository's default.

A request or model parameter of `num_gpu: 0` also explicitly selects the CPU.

## Missing backend

```sh
dpkg-query -W ollama ollama-backend-vulkan vulkan-loader-android libc++
ls "$PREFIX/lib/ollama/vulkan/libggml-vulkan.so"
```

The Ollama and backend package versions must match. Refresh the package index
if downloads return 404 errors, then install the packages again:

```sh
apt-get update
apt-get install --no-install-recommends ollama ollama-backend-vulkan vulkan-loader-android libc++
```

These are the official
[Termux backend](https://github.com/termux/termux-packages/blob/master/packages/ollama/ollama-backend-vulkan.subpackage.sh)
and [Android loader](https://github.com/termux/termux-packages/blob/master/packages/vulkan-loader-android/build.sh)
packages.

## Missing C++ symbol

If the runner says `cannot locate symbol`, update `libc++` and make sure
Termux's library directory comes before any bundled copies:

```sh
apt-get install libc++
```

The installed launcher sets this search order for the Ollama server. It does
not change library paths globally for other programs.

## Only a software Vulkan device appears

Run `ollama-gpu-check`. The tested phone reports `Adreno (TM) 840`.
`llvmpipe` is a software renderer, so its presence does not prove that the
physical GPU is being used.

This setup uses `vulkan-loader-android`, which links to Android's system loader.
Check it with:

```sh
readlink -f "$PREFIX/lib/libvulkan.so"
```

On the tested phone it resolves to `/system/lib64/libvulkan.so`. Other drivers
and devices may behave differently. Keep details of the GPU, Android version,
Ollama version, and the runner error when reporting a problem.

## Model not found

`ollama-gpu-check --generate MODEL` uses an installed model and does not pull
one. Run `ollama list` and use the full model name from that output.

The diagnostic command connects to `http://127.0.0.1:11434`. If your server uses
a different address or port, use `ollama ps` against that server and inspect its
log instead.

## Memory pressure or partial GPU use

The CPU and GPU share RAM with Android. Close other large apps, use a smaller
model, and test with a 4K context. A model named or configured for 32K may set
its own context length and override the launcher's default.

Partial GPU allocation can be valid. Check `ollama ps` and the server's
`offloaded N/M layers` message. `100% GPU` describes the model's placement;
the application still uses the CPU for other work.

The driver's memory estimate can exceed physical RAM. Do not use that estimate
as a model size limit. This setup does not enable the phone's NPU.
