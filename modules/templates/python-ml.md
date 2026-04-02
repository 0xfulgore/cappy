# {{PROJECT_NAME}} — Development Guide

## Tech Stack
- **Language**: Python {{PYTHON_VERSION}}
- **ML**: {{ML_FRAMEWORK}}
- **Data**: pandas, numpy
- **API**: {{API_FRAMEWORK}}
- **Environment**: {{ENV_MANAGER}}

## Commands
```bash
pytest                 # Run tests
pytest --cov           # Tests with coverage
mypy .                 # Type check
ruff check .           # Lint
ruff format .          # Format
python -m {{ENTRY}}    # Run
```

## Architecture
- `src/` — Main application code
- `src/models/` — ML model definitions and training
- `src/data/` — Data loading, preprocessing, feature engineering
- `src/api/` — API endpoints (if applicable)
- `src/utils/` — Shared utilities
- `tests/` — Test suite
- `notebooks/` — Jupyter notebooks for exploration
- `configs/` — Training configs, hyperparameters

## Code Style
- Type hints on all function signatures
- Docstrings (Google style) on all public functions
- No star imports (`from x import *`)
- Use pathlib over os.path
- Use dataclasses or pydantic for structured data
- Notebooks are for exploration only — production code goes in `src/`
