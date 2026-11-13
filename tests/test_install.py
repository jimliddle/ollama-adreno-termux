"""Exercise install, runtime selection, and rollback without changing Termux."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ollama-adreno-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home with spaces"
        self.prefix = Path(self.temp.name) / "prefix with spaces"
        self.home.mkdir()
        (self.prefix / "bin").mkdir(parents=True)
        (self.prefix / "lib/ollama/vulkan").mkdir(parents=True)
        (self.prefix / "lib/ollama/vulkan/libggml-vulkan.so").touch()
        (self.prefix / "bin/bash").symlink_to(shutil.which("bash"))
        (self.prefix / "bin/python").symlink_to(shutil.which("python3") or shutil.which("python"))
        binary = self.prefix / "bin/ollama"
        binary.write_text(
            "#!" + str(shutil.which("python3") or shutil.which("python")) + "\n"
            "import os,json,sys\n"
            "print(json.dumps({'args':sys.argv[1:], 'env':dict(os.environ)}))\n"
        )
        binary.chmod(0o700)
        self.env = os.environ.copy()
        self.env.update(HOME=str(self.home), PREFIX=str(self.prefix), LD_LIBRARY_PATH="/bundled/old-runtime")
        for key in list(self.env):
            if key.startswith("OLLAMA_") or key in ("XDG_CONFIG_HOME", "XDG_STATE_HOME"):
                self.env.pop(key)

    def run_script(self, script, *args, check=True):
        return subprocess.run(
            ["bash", str(ROOT / script), *args], env=self.env, capture_output=True, text=True, check=check
        )

    def invoke(self, *args, **overrides):
        # Explicit bash keeps the test portable when the fake prefix has spaces.
        result = subprocess.run(
            ["bash", str(self.home / ".local/bin/ollama"), *args],
            env=dict(self.env, **overrides), capture_output=True, text=True, check=True,
        )
        return json.loads(result.stdout)

    def test_startup_settings_and_client_passthrough(self):
        self.run_script("install.sh", "--skip-packages")
        server = self.invoke("serve")
        self.assertEqual(server["args"], ["serve"])
        self.assertEqual(server["env"]["OLLAMA_IGPU_ENABLE"], "1")
        self.assertEqual(server["env"]["OLLAMA_VULKAN"], "1")
        self.assertEqual(server["env"]["OLLAMA_CONTEXT_LENGTH"], "4096")
        self.assertEqual(server["env"]["LD_LIBRARY_PATH"].split(":")[0], str(self.prefix / "lib"))
        override = self.invoke("start", OLLAMA_CONTEXT_LENGTH="8192", OLLAMA_VULKAN="0")
        self.assertEqual(override["env"]["OLLAMA_CONTEXT_LENGTH"], "8192")
        self.assertEqual(override["env"]["OLLAMA_VULKAN"], "0")
        client = self.invoke("run", "a model", "prompt with spaces")
        self.assertEqual(client["args"], ["run", "a model", "prompt with spaces"])
        self.assertEqual(client["env"]["LD_LIBRARY_PATH"], "/bundled/old-runtime")
        self.assertNotIn("OLLAMA_IGPU_ENABLE", client["env"])

    def test_reinstall_and_rollback_restore_existing_files(self):
        targets = [self.home / ".local/bin/ollama", self.home / ".local/bin/ollama-gpu-check",
                   self.home / ".config/ollama-adreno-termux/gpu.env"]
        for i, target in enumerate(targets):
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(f"previous file {i}\n")
        self.run_script("install.sh", "--skip-packages")
        config = targets[2]
        config.write_text(config.read_text() + "\n# user edit\n")
        self.run_script("install.sh", "--skip-packages")
        self.assertIn("# user edit", config.read_text())
        self.run_script("uninstall.sh")
        for i, target in enumerate(targets):
            self.assertEqual(target.read_text(), f"previous file {i}\n")
        saved = list((self.home / ".local/state/ollama-adreno-termux").glob("uninstalled.*/configuration"))
        self.assertEqual(len(saved), 1)
        self.assertIn("# user edit", saved[0].read_text())
        self.assertIn("No active installation", self.run_script("uninstall.sh").stdout)

    def test_clean_install_rollback_with_xdg_paths(self):
        self.env.update(XDG_CONFIG_HOME=str(self.home / "custom config"), XDG_STATE_HOME=str(self.home / "custom state"))
        self.run_script("install.sh", "--skip-packages")
        self.assertEqual(self.invoke("serve")["env"]["OLLAMA_IGPU_ENABLE"], "1")
        self.run_script("uninstall.sh")
        self.assertFalse((self.home / ".local/bin/ollama").exists())
        self.assertFalse((self.home / "custom config/ollama-adreno-termux/gpu.env").exists())

    def test_missing_backend_does_not_replace_launcher(self):
        (self.prefix / "lib/ollama/vulkan/libggml-vulkan.so").unlink()
        result = self.run_script("install.sh", "--skip-packages", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / ".local/bin/ollama").exists())


if __name__ == "__main__":
    unittest.main()
