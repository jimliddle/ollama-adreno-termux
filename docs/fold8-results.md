# Fold 8 test results

Tested on 13 November 2026 using an existing model stored on the phone.

| Item | Value |
| --- | --- |
| Phone | Samsung Galaxy Z Fold 8 |
| Model number | SM-F971B |
| SoC reported by Android | SM8850 |
| GPU reported by Vulkan | Adreno (TM) 840 |
| Android | 17 |
| Physical RAM reported by Linux | 15,435,236 KiB |
| Ollama | 0.40.15, official Termux package |
| Vulkan backend package | ollama-backend-vulkan 0.40.15 |
| Android Vulkan loader package | vulkan-loader-android 30 |
| C++ runtime package | libc++ 30 |
| Model | qwen3:4b-instruct-2507-q4_K_M |
| Context | 4096 |

## What failed before the fix

The original Ollama 0.31.1 installation contained CPU backends but no Vulkan
backend. After installing the current backend, the runner failed to load with
this error:

```text
cannot locate symbol "_ZNSt6__ndk113__hash_memoryEPKvm"
```

Termux's C++ runtime needed updating, and a different command-line tool had
added its own older runtime to `LD_LIBRARY_PATH`. Updating the package alone
did not resolve that search order. Putting Termux's library directory first
allowed the runner to start.

Ollama then found the GPU but skipped it:

```text
dropping integrated GPU; to enable, set OLLAMA_IGPU_ENABLE=1
```

Enabling that setting allowed the model to use the GPU.

## Verified result

The server log reported:

```text
llama_prepare_model_devices: using device Vulkan0 (Adreno (TM) 840)
load_tensors: offloaded 37/37 layers to GPU
load_tensors:      Vulkan0 model buffer size =  2375.91 MiB
llama_kv_cache:    Vulkan0 KV buffer size =   576.00 MiB
sched_reserve:    Vulkan0 compute buffer size =    81.01 MiB
```

The device line above omits the driver's free-memory estimate. The remaining
lines are copied from the test log.

`ollama ps` showed `100% GPU`. The `/api/ps` response reported 3,180,247,121
bytes for both total model allocation and GPU allocation.

The prompt was `Reply with exactly: GPU test successful`. The response was
`GPU test successful`.

The API reported:

| Measurement | Value |
| --- | --- |
| Total request time | 8.033 seconds |
| Model load time | 5.967 seconds |
| Prompt tokens | 15 |
| Generated tokens | 4 |
| Generation time | 0.206 seconds |

Four generated tokens are too few for a useful performance benchmark. This test
confirms successful GPU inference. It does not establish sustained speed,
battery use, temperature, or performance against the CPU. Larger models and
longer contexts were not tested for this result.

The phone has about 14.7 GiB of physical RAM, while the Vulkan driver reported
18.7 GiB. That larger figure should not be treated as available model memory.
