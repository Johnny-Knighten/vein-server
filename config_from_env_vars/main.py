#!/usr/bin/env python3
import filecmp
import os
import logging
from argparse import ArgumentParser
from configparser import RawConfigParser
from pathlib import Path
import shutil
import sys
import re
from typing import Dict

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)


class MaintainCaseConfigParser(RawConfigParser):
    def optionxform(self, optionstr):
        return optionstr


def process_env_vars() -> Dict[str, Dict[str, Dict[str, str]]]:
    """
    Process environment variables in the format:
    CONFIG_FILE_<filename>_SECTION_<section>_VAR_<variable>=<value>

    Section and variable names support SLASH and DOT replacements for / and . characters.
    Trailing numbers in variable names are converted to array syntax [N].
    """
    config_files: Dict[str, Dict[str, Dict[str, str]]] = {}
    for key, value in os.environ.items():
        if not key.startswith("CONFIG_FILE_"):
            continue

        # Remove CONFIG_FILE_ prefix
        remainder = key[len("CONFIG_FILE_") :]

        # Find _SECTION_ delimiter
        section_marker = "_SECTION_"
        section_idx = remainder.find(section_marker)
        if section_idx == -1:
            logging.warning(
                f"Invalid config environment variable (missing _SECTION_): {key}"
            )
            continue

        file_name = remainder[:section_idx]
        remainder = remainder[section_idx + len(section_marker) :]

        # Find _VAR_ delimiter
        var_marker = "_VAR_"
        var_idx = remainder.find(var_marker)
        if var_idx == -1:
            logging.warning(
                f"Invalid config environment variable (missing _VAR_): {key}"
            )
            continue

        section_name = remainder[:var_idx]
        var_name = remainder[var_idx + len(var_marker) :]

        # Apply SLASH and DOT replacements to section name
        section_name = section_name.replace("SLASH", "/").replace("DOT", ".")
        section_name = (
            section_name.replace("_/_", "/")
            .replace("/_", "/")
            .replace("_/", "/")
            .replace("_._", ".")
            .replace("_.", ".")
            .replace("._", ".")
        )

        # Apply SLASH and DOT replacements to variable name
        var_name = var_name.replace("SLASH", "/").replace("DOT", ".")
        var_name = (
            var_name.replace("_/_", "/")
            .replace("/_", "/")
            .replace("_/", "/")
            .replace("_._", ".")
            .replace("_.", ".")
            .replace("._", ".")
        )

        # Convert trailing numbers to array syntax
        var_name = re.sub(r"(\d+)$", r"[\1]", var_name)

        if not file_name or not section_name or not var_name:
            logging.warning(
                f"Invalid config environment variable (empty component): {key}"
            )
            continue

        if file_name not in config_files:
            config_files[file_name] = {}
        if section_name not in config_files[file_name]:
            config_files[file_name][section_name] = {}

        config_files[file_name][section_name][var_name] = value

    return config_files


def update_ini_files(
    config_data: Dict[str, Dict[str, Dict[str, str]]], path: str
) -> None:
    for file_name, sections in config_data.items():
        config_parser = MaintainCaseConfigParser(strict=False)
        file_path = os.path.join(path, f"{file_name}.ini")

        try:
            if not Path(file_path).exists():
                logging.warning(
                    f"File not found: {file_path}. A new file will be created."
                )
            config_parser.read(file_path)

            for section, vars in sections.items():
                if not config_parser.has_section(section):
                    config_parser.add_section(section)
                for var, value in vars.items():
                    config_parser.set(section, var, value)
                    logging.info(f"Saving {section} {var}={value} to {file_path}")

            with open(file_path, "w") as config_file:
                config_parser.write(config_file, space_around_delimiters=False)

        except Exception as e:
            logging.error(f"Error updating file {file_name}.ini: {e}")
            continue


def backup_existing_ini_files(path: str) -> None:
    for file_name in os.listdir(path):
        if not file_name.endswith(".ini"):
            continue

        file_path = os.path.join(path, file_name)
        backup_path = os.path.join(path, f"{file_name}.backup")

        counter = 1
        while Path(backup_path).exists():
            backup_path = os.path.join(path, f"{file_name}.backup{counter}")
            counter += 1

        try:
            logging.info(f"Creating backup of {file_path} to {backup_path}")
            shutil.move(file_path, backup_path)
        except Exception as e:
            logging.error(f"Error creating backup of {file_name}: {e}")
            continue


def get_latest_backup_file(base_file_path: str):
    base_file_name = os.path.basename(base_file_path)
    directory = os.path.dirname(base_file_path)
    backup_files = sorted(
        Path(directory).glob(f"{base_file_name}.backup*"), reverse=True
    )
    return str(backup_files[0]) if backup_files else ""


def compare_and_cleanup_configs(path: str):
    for file in Path(path).glob("*.ini"):
        latest_backup = get_latest_backup_file(str(file))

        if not latest_backup:
            logging.info(f"No backups exist for: {file}")
            continue

        if Path(latest_backup).exists() and filecmp.cmp(
            file, latest_backup, shallow=False
        ):
            os.remove(latest_backup)
            logging.info(f"New config matches old, backup removed: {latest_backup}")
        else:
            logging.info(
                f"Configuration changed, latest backup retained: {latest_backup}"
            )


def main():
    parser = ArgumentParser(
        description="Update ini configuration files based on environment variables."
    )
    parser.add_argument(
        "--path",
        dest="config_directory",
        type=str,
        help="Path to store created ini files.",
        default="/vein-server/server/Vein/Saved/Config/LinuxServer",
    )
    args = parser.parse_args()

    if not os.path.isdir(args.config_directory):
        logging.error(
            f"The specified directory does not exist: {args.config_directory}"
        )
        sys.exit(1)

    backup_existing_ini_files(args.config_directory)
    config_data = process_env_vars()
    update_ini_files(config_data, args.config_directory)
    compare_and_cleanup_configs(args.config_directory)


if __name__ == "__main__":
    main()
