"""FastAPI backend for vespa_tdx easy-tdx raw K-line data."""

from .easy_tdx_indicator_patch import install_easy_tdx_indicator_patch

install_easy_tdx_indicator_patch()
