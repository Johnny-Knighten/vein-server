# test_main.py

import logging
import unittest
from pathlib import Path
from unittest import mock
from unittest.mock import MagicMock, mock_open, patch

from config_from_env_vars.main import (
    backup_changed_ini_files,
    file_differs_from_backup,
    get_latest_backup_file,
    process_env_vars,
    update_ini_files,
)

# logging.disable(logging.CRITICAL)


class TestConfigFromEnvVars(unittest.TestCase):
    def setUp(self):
        self.env_patcher = patch.dict("os.environ", clear=True)
        self.env_patcher.start()
        logging.disable(logging.NOTSET)

    def tearDown(self):
        self.env_patcher.stop()
        logging.disable(logging.ERROR)

    @patch.dict(
        "os.environ",
        {
            "CONFIG_FILE_GameUserSettings_SECTION_ServerSettings_VAR_DifficultyOffset": "0.25"
        },
    )
    def test_process_env_vars_simple(self):
        result = process_env_vars()
        self.assertEqual(
            result,
            {"GameUserSettings": {"ServerSettings": {"DifficultyOffset": "0.25"}}},
        )

    @patch.dict(
        "os.environ",
        {
            "CONFIG_FILE_GameUserSettings_SECTION_ServerSettings_VAR_DifficultyOffset": "0.25",
            "CONFIG_FILE_AppearanceSettings_SECTION_ServerSettings_VAR_DifficultyOffset": "0.75",
        },
    )
    def test_process_env_vars_with_two_files(self):
        result = process_env_vars()
        expected = {
            "GameUserSettings": {"ServerSettings": {"DifficultyOffset": "0.25"}},
            "AppearanceSettings": {"ServerSettings": {"DifficultyOffset": "0.75"}},
        }
        self.assertEqual(result, expected)

    @patch.dict(
        "os.environ",
        {
            "CONFIG_FILE_GameUserSettings_SECTION_ServerSettings_VAR_DifficultyOffset": "0.25",
            "CONFIG_FILE_GameUserSettings_SECTION_PlayerSettings_VAR_DifficultyOffset": "0.75",
        },
    )
    def test_process_env_vars_with_two_sections(self):
        result = process_env_vars()
        expected = {
            "GameUserSettings": {
                "ServerSettings": {"DifficultyOffset": "0.25"},
                "PlayerSettings": {"DifficultyOffset": "0.75"},
            }
        }
        self.assertEqual(result, expected)

    @patch.dict(
        "os.environ",
        {
            "CONFIG_FILE_GameUserSettings_SECTION_ServerSettings_VAR_DifficultyOffset": "0.25",
            "CONFIG_FILE_GameUserSettings_SECTION_ServerSettings_VAR_XPOffset": "0.75",
        },
    )
    def test_process_env_vars_with_two_vars(self):
        result = process_env_vars()
        expected = {
            "GameUserSettings": {
                "ServerSettings": {"DifficultyOffset": "0.25", "XPOffset": "0.75"}
            }
        }
        self.assertEqual(result, expected)

    @patch.dict(
        "os.environ",
        {
            "CONFIG_FILE_GameUserSettings_SECTION_Server_DOT_Settings_VAR_DifficultyOffset": "0.25"
        },
    )
    def test_process_env_vars_with_dot_in_section(self):
        result = process_env_vars()
        self.assertEqual(
            result,
            {"GameUserSettings": {"Server.Settings": {"DifficultyOffset": "0.25"}}},
        )

    @patch.dict(
        "os.environ",
        {
            "CONFIG_FILE_GameUserSettings_SECTION_Server_SLASH_Settings_VAR_DifficultyOffset": "0.25"
        },
    )
    def test_process_env_vars_with_slash_in_section(self):
        result = process_env_vars()
        self.assertEqual(
            result,
            {"GameUserSettings": {"Server/Settings": {"DifficultyOffset": "0.25"}}},
        )

    @patch.dict(
        "os.environ",
        {
            "CONFIG_FILE_Game_SECTION_ServerSettings_VAR_PlayerBaseStatsMultipliers7": "6.0"
        },
    )
    def test_process_env_vars_with_number_in_varname(self):
        result = process_env_vars()
        self.assertEqual(
            result,
            {"Game": {"ServerSettings": {"PlayerBaseStatsMultipliers[7]": "6.0"}}},
        )

    @patch.dict(
        "os.environ",
        {"CONFIG_FILE_Game_SECTION_ConsoleVariables_VAR_vein_DOT_PvP": "True"},
    )
    def test_process_env_vars_with_dot_in_varname(self):
        result = process_env_vars()
        self.assertEqual(
            result,
            {"Game": {"ConsoleVariables": {"vein.PvP": "True"}}},
        )

    @patch.dict(
        "os.environ",
        {
            "CONFIG_FILE_Game_SECTION_ConsoleVariables_VAR_vein_DOT_AISpawner_DOT_Enabled": "True"
        },
    )
    def test_process_env_vars_with_multiple_dots_in_varname(self):
        result = process_env_vars()
        self.assertEqual(
            result,
            {"Game": {"ConsoleVariables": {"vein.AISpawner.Enabled": "True"}}},
        )

    @patch.dict(
        "os.environ", {"CONFIG_FILE_GameUserSettings_VAR_DifficultyOffset": "0.25"}
    )
    def test_process_env_vars_with_missing_section(self):
        result = process_env_vars()
        self.assertEqual(result, {})

    @patch.dict(
        "os.environ", {"CONFIG_FILE_GameUserSettings_SECTION_ServerSettings": "0.25"}
    )
    def test_process_env_vars_with_missing_var(self):
        result = process_env_vars()
        self.assertEqual(result, {})

    @patch("builtins.open", new_callable=mock_open)
    @patch("config_from_env_vars.main.MaintainCaseConfigParser")
    def test_update_ini_files_single_file(self, mock_config, mock_file):
        mock_config_data = {
            "GameUserSettings": {
                "ServerSettings": {
                    "DifficultyOffset": "0.25",
                }
            }
        }
        update_ini_files(mock_config_data, "/fake/path")
        mock_file.assert_called_once_with("/fake/path/GameUserSettings.ini", "w")
        mock_config.return_value.set.assert_called_once_with(
            "ServerSettings", "DifficultyOffset", "0.25"
        )
        mock_config.return_value.write.assert_called_once()

    @patch("builtins.open", new_callable=mock_open)
    @patch("config_from_env_vars.main.MaintainCaseConfigParser")
    def test_update_ini_files_multiple_file(self, mock_config, mock_file):
        mock_config_data = {
            "GameUserSettings": {
                "ServerSettings": {
                    "DifficultyOffset": "0.25",
                }
            },
            "GameAppearance": {
                "Logo": {
                    "Path": "/path/to/logo.png",
                }
            },
        }
        update_ini_files(mock_config_data, "/fake/path")
        mock_file.assert_any_call("/fake/path/GameUserSettings.ini", "w")
        mock_file.assert_any_call("/fake/path/GameAppearance.ini", "w")
        self.assertEqual(mock_config.return_value.write.call_count, 2)

    @patch("builtins.open", new_callable=mock_open)
    @patch("config_from_env_vars.main.MaintainCaseConfigParser")
    def test_update_ini_files_no_data_to_write(self, mock_config, mock_file):
        mock_config_data = {}
        update_ini_files(mock_config_data, "/fake/path")
        mock_file.assert_not_called()
        mock_config.return_value.set.assert_not_called()
        mock_config.return_value.write.assert_not_called()

    # Tests for file_differs_from_backup

    @patch("config_from_env_vars.main.get_latest_backup_file")
    @patch("config_from_env_vars.main.Path")
    def test_file_differs_from_backup_no_backup(self, mock_path, mock_get_latest):
        """Returns True when no backup exists."""
        mock_get_latest.return_value = ""

        result = file_differs_from_backup("/fake/path/config.ini")

        self.assertTrue(result)

    @patch("config_from_env_vars.main.get_latest_backup_file")
    @patch("config_from_env_vars.main.filecmp.cmp")
    @patch("config_from_env_vars.main.Path")
    def test_file_differs_from_backup_identical(
        self, mock_path, mock_cmp, mock_get_latest
    ):
        """Returns False when file matches backup."""
        mock_get_latest.return_value = "/fake/path/config.ini.backup"
        mock_path.return_value.exists.return_value = True
        mock_cmp.return_value = True  # Files are identical

        result = file_differs_from_backup("/fake/path/config.ini")

        self.assertFalse(result)
        mock_cmp.assert_called_once_with(
            "/fake/path/config.ini", "/fake/path/config.ini.backup", shallow=False
        )

    @patch("config_from_env_vars.main.get_latest_backup_file")
    @patch("config_from_env_vars.main.filecmp.cmp")
    @patch("config_from_env_vars.main.Path")
    def test_file_differs_from_backup_different(
        self, mock_path, mock_cmp, mock_get_latest
    ):
        """Returns True when file differs from backup."""
        mock_get_latest.return_value = "/fake/path/config.ini.backup"
        mock_path.return_value.exists.return_value = True
        mock_cmp.return_value = False  # Files are different

        result = file_differs_from_backup("/fake/path/config.ini")

        self.assertTrue(result)

    # Tests for backup_changed_ini_files

    @patch("config_from_env_vars.main.file_differs_from_backup")
    @patch("config_from_env_vars.main.shutil.copy2")
    @patch("config_from_env_vars.main.Path")
    def test_backup_changed_ini_files_skips_unchanged(
        self, mock_path, mock_copy, mock_differs
    ):
        """Does not create backup when file unchanged from backup."""
        mock_path.return_value.exists.return_value = True
        mock_differs.return_value = False  # File unchanged

        backup_changed_ini_files(["config.ini"], "/fake/path")

        mock_copy.assert_not_called()

    @patch("config_from_env_vars.main.file_differs_from_backup")
    @patch("config_from_env_vars.main.shutil.copy2")
    @patch("config_from_env_vars.main.Path")
    def test_backup_changed_ini_files_backs_up_changed(
        self, mock_path, mock_copy, mock_differs
    ):
        """Creates backup when file differs from backup."""
        path_instance = MagicMock()
        mock_path.return_value = path_instance
        # First call: file exists, second call: backup path doesn't exist
        path_instance.exists.side_effect = [True, False]
        mock_differs.return_value = True  # File changed

        backup_changed_ini_files(["config.ini"], "/fake/path")

        mock_copy.assert_called_once_with(
            "/fake/path/config.ini", "/fake/path/config.ini.backup"
        )

    @patch("config_from_env_vars.main.file_differs_from_backup")
    @patch("config_from_env_vars.main.shutil.copy2")
    @patch("config_from_env_vars.main.Path")
    def test_backup_changed_ini_files_skips_nonexistent(
        self, mock_path, mock_copy, mock_differs
    ):
        """Does not backup files that don't exist."""
        mock_path.return_value.exists.return_value = False

        backup_changed_ini_files(["config.ini"], "/fake/path")

        mock_copy.assert_not_called()
        mock_differs.assert_not_called()

    @patch("config_from_env_vars.main.file_differs_from_backup")
    @patch("config_from_env_vars.main.shutil.copy2")
    @patch("config_from_env_vars.main.Path")
    def test_backup_changed_ini_files_increments_backup_number(
        self, mock_path, mock_copy, mock_differs
    ):
        """Increments backup number when backup already exists."""
        path_instance = MagicMock()
        mock_path.return_value = path_instance
        # file exists, backup exists, backup1 exists, backup2 doesn't exist
        path_instance.exists.side_effect = [True, True, True, False]
        mock_differs.return_value = True

        backup_changed_ini_files(["config.ini"], "/fake/path")

        mock_copy.assert_called_once_with(
            "/fake/path/config.ini", "/fake/path/config.ini.backup2"
        )

    @patch("config_from_env_vars.main.file_differs_from_backup")
    @patch("config_from_env_vars.main.shutil.copy2")
    @patch("config_from_env_vars.main.Path")
    def test_backup_uses_copy_not_move(self, mock_path, mock_copy, mock_differs):
        """Verifies copy2 is used (preserves original file)."""
        path_instance = MagicMock()
        mock_path.return_value = path_instance
        path_instance.exists.side_effect = [True, False]
        mock_differs.return_value = True

        backup_changed_ini_files(["config.ini"], "/fake/path")

        # Verify copy2 was called (not move)
        mock_copy.assert_called_once()

    @patch("config_from_env_vars.main.file_differs_from_backup")
    @patch("config_from_env_vars.main.shutil.copy2")
    @patch("config_from_env_vars.main.Path")
    def test_backup_changed_ini_files_error_handling(
        self, mock_path, mock_copy, mock_differs
    ):
        """Handles errors gracefully during backup."""
        path_instance = MagicMock()
        mock_path.return_value = path_instance
        path_instance.exists.side_effect = [True, False]
        mock_differs.return_value = True
        mock_copy.side_effect = OSError("Mocked file access error")

        with self.assertLogs(level="ERROR") as log:
            backup_changed_ini_files(["config.ini"], "/fake/path")

        self.assertIn("Mocked file access error", log.output[0])

    @patch("config_from_env_vars.main.Path")
    def test_get_latest_backup_file_with_multiple_backups(self, mock_path):
        directory = "/fake/path"
        base_file_name = "config.ini"
        mock_backup_files = [
            Path(f"{directory}/{base_file_name}.backup{i}") for i in range(1, 4)
        ]
        mock_path.return_value.glob.return_value = mock_backup_files

        latest_backup = get_latest_backup_file(f"{directory}/{base_file_name}")

        self.assertEqual(latest_backup, f"{directory}/{base_file_name}.backup3")

    @patch("config_from_env_vars.main.Path")
    def test_get_latest_backup_file_with_single_backup(self, mock_path):
        directory = "/fake/path"
        base_file_name = "config.ini"
        mock_backup_files = [Path(f"{directory}/{base_file_name}.backup")]
        mock_path.return_value.glob.return_value = mock_backup_files

        latest_backup = get_latest_backup_file(f"{directory}/{base_file_name}")

        self.assertEqual(latest_backup, f"{directory}/{base_file_name}.backup")

if __name__ == "__main__":
    unittest.main()
