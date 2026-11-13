# Ollama on Adreno with Termux

Run Ollama on a phone's Adreno GPU using the official Termux packages.

This was tested on a Samsung Galaxy Z Fold 8 with an Adreno 840 and Android 17.
Qwen 4B loaded all 37 layers onto the GPU, and `ollama ps` reported `100% GPU`.
Other phones have not been tested here.

## What this fixes

Ollama can fall back to the CPU even when the phone has a working GPU. On the
tested phone there were three problems:

- The `ollama-backend-vulkan` package was missing.
- Ollama needed `OLLAMA_IGPU_ENABLE=1` to use the integrated GPU.
- An older C++ library bundled with another command-line tool took precedence
  over Termux's library and stopped the model runner from loading.

The installer adds the missing packages and puts a launcher in `~/.local/bin`.
The launcher enables Vulkan and the integrated GPU when starting the server. It
also makes the server use Termux's C++ library first.

The code comes from [Ollama](https://github.com/ollama/ollama) and
[Termux](https://github.com/termux/termux-packages/tree/master/packages/ollama).
This repository supplies startup settings and checks. There is no custom Ollama
build to maintain.

## Install

Use native Termux on an ARM64 Android phone. Run these commands inside Termux,
rather than a Linux distribution running under proot.

```sh
pkg install git
git clone https://github.com/jimliddle/ollama-adreno-termux.git
cd ollama-adreno-termux
bash install.sh
export PATH="$HOME/.local/bin:$PATH"
hash -r
```

Add the `export PATH` line to `~/.bashrc`, or `~/.zshrc` if you use zsh, so new
shells find the launcher. If that line is already present, leave it as it is.

The installer refreshes the package list and installs or updates these packages:

```text
ollama
ollama-backend-vulkan
vulkan-loader-android
libc++
python
```

It backs up existing files before replacing them. It does not edit model files,
change Android drivers, or restart a running server. Python is used by the
diagnostic command.

If those packages are already installed, use `bash install.sh --skip-packages`.

## Start Ollama

Stop any existing Ollama server through the terminal or app that started it.
Then start it again:

```sh
ollama serve
```

Keep that terminal open. In another Termux session, check that the launcher is
being used:

```sh
command -v ollama
```

The path should end in `.local/bin/ollama`. Starting
`$PREFIX/bin/ollama serve` directly bypasses the launcher and its settings.

## Check GPU use

List installed models, then test one of them:

```sh
ollama list
ollama-gpu-check --generate qwen3:4b-instruct-2507-q4_K_M
ollama ps
```

Replace the example model name with one from your list. The check does not
download a model. It uses a 4,096-token context for the test.

The check lists the Vulkan device, sends a short prompt to the local Ollama
server, and checks GPU memory allocation for that model. `ollama ps` shows
whether it is fully or partly on the GPU. To check device discovery without
generating text, run `ollama-gpu-check` on its own.

Finding a Vulkan device does not prove that a model is using it. Check the loaded
model as well. The server log can also confirm this with a line such as:

```text
load_tensors: offloaded 37/37 layers to GPU
```

## Settings

Settings are saved in `~/.config/ollama-adreno-termux/gpu.env`, or under
`$XDG_CONFIG_HOME` when set. They apply to `ollama serve` and `ollama start`.

| Setting | Default | Purpose |
| --- | --- | --- |
| `OLLAMA_VULKAN` | `1` | Enable the Vulkan backend |
| `OLLAMA_IGPU_ENABLE` | `1` | Allow the integrated GPU |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Keep one model loaded at a time |
| `OLLAMA_NUM_PARALLEL` | `1` | Run one request at a time |
| `OLLAMA_CONTEXT_LENGTH` | `4096` | Set the default context length |

Existing environment values take precedence. Model parameters and request
options can also set the context length. A model configured for 32K can still
request 32K; this launcher does not rewrite it.

The GPU shares memory with Android. Start with a small model and a 4K context.
The amount of memory reported by the driver is not a reliable measure of how
much memory is available for a model.

## Undo the setup

```sh
cd ollama-adreno-termux
bash uninstall.sh
hash -r
```

This restores the files that existed before installation. Copies of the removed
files, including any edits, are kept under
`~/.local/state/ollama-adreno-termux` or `$XDG_STATE_HOME` when set. Packages and
models stay installed. Restart Ollama for the change to take effect.

## Results and troubleshooting

- [Tested Fold 8 setup](docs/fold8-results.md)
- [Troubleshooting](docs/troubleshooting.md)

For a different approach that builds Ollama from source, see
[llamux](https://github.com/JediRhymeTrix/llamux).

## Check the scripts

The install and rollback tests use temporary directories and a dummy Ollama
binary. They do not install packages or change your running server.

```sh
python -m unittest discover -s tests -v
```

MIT licence. See [LICENSE](LICENSE).
