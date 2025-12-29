# Contributing to Vein Server

Thank you for your interest in contributing to the Vein Server Docker project! This document provides guidelines for contributing.

## Project Goals

This project aims to provide a simple and easy-to-use Docker image for running Vein dedicated game servers. We strive to:

- Maintain feature parity with [ark-sa-server](https://github.com/Johnny-Knighten/ark-sa-server)
- Provide sensible defaults while allowing rich configurability
- Keep the codebase simple and maintainable

## Workflow

We use GitHub Flow for development:

1. **Branch from `next`** - Create feature branches from the `next` branch
2. **Use descriptive branch names** - Follow the naming convention:
   - `feat/` - New features
   - `fix/` - Bug fixes
   - `docs/` - Documentation changes
   - `refactor/` - Code refactoring
   - `chore/` - Maintenance tasks
3. **Run tests before creating PRs** - Ensure all linting passes
4. **Target PRs to `next`** - All pull requests should target the `next` branch

## Coding Standards

### Shell Scripts

- Use 2-space indentation
- Use meaningful variable names
- Add comments for complex logic
- Run shellcheck before committing:
  ```bash
  shellcheck bin/*.sh
  ```

### Docker

- Follow Dockerfile best practices
- Minimize layer count where practical
- Use hadolint for Dockerfile linting

## Commit Messages

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

### Format

```
<type>: <description>

[optional body]

[optional footer]
```

### Types

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `refactor:` - Code refactoring (no feature change)
- `chore:` - Maintenance tasks
- `test:` - Adding or updating tests
- `perf:` - Performance improvements

### Examples

```
feat: add scheduled backup retention policy

fix: correct healthcheck timeout logic

docs: update README configuration section
```

### Breaking Changes

For breaking changes, add `!` after the type:

```
feat!: change environment variable naming convention

BREAKING CHANGE: All ENV vars now use VEIN_ prefix
```

## Testing

Before submitting a PR:

1. **Build the Docker image:**
   ```bash
   docker build -t vein-server:dev .
   ```

2. **Run shellcheck on scripts:**
   ```bash
   shellcheck bin/*.sh
   ```

3. **Test with docker-compose:**
   ```bash
   docker-compose up
   ```

4. **Verify your changes work as expected**

## Pull Request Process

1. Ensure your code follows the coding standards
2. Update documentation if needed
3. Add a clear description of changes
4. Reference any related issues
5. Wait for review and address feedback

## Branching Strategy

- **`main`** - Stable releases only
- **`next`** - Integration branch for upcoming release

All feature branches should be created from and merged into `next`.

## License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.
