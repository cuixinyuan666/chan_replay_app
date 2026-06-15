"""FastAPI backend for vespa_tdx easy-tdx raw K-line data."""

from .easy_tdx_indicator_patch import install_easy_tdx_indicator_patch
from .a_replay_contract_hardening import (
    install_backend_kline_session_cache,
    install_bsp_history_contract,
)

install_easy_tdx_indicator_patch()
install_backend_kline_session_cache()
install_bsp_history_contract()
