#!/bin/bash
set -e  # Exit on error for critical operations

echo "Installing development tools..."

# 1. Update apt cache
sudo apt-get update

# 2. Install Docker CLI (for Docker-from-host approach)
# Add Docker's official GPG key and repository
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce-cli docker-compose-plugin

# 3. Install shellcheck (critical for all PRs)
sudo apt-get install -y shellcheck

# 4. Install shfmt (shell formatter)
sudo apt-get install -y shfmt || echo "shfmt not in apt, will use alternative method"

# 5. Install GitHub CLI (gh)
# Official method: Add GitHub's apt repository
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
sudo apt-get install -y gh

# 6. Install Claude Code CLI
# Install Node.js (required for Claude Code)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Claude Code CLI globally
sudo npm install -g @anthropic-ai/claude-code

# 7. Verify installations
echo "Verifying installations..."
docker --version
docker compose version
shellcheck --version
shfmt -version || echo "shfmt not available (non-critical)"
gh --version
git --version
node --version
npm --version
claude --version

echo "✓ Development tools installed successfully!"
