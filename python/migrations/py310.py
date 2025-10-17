# Compatibility module for Python 3.10+
try:
    from enum import StrEnum as StrEnum310
except ImportError:
    from enum import Enum
    class StrEnum310(str, Enum):
        pass
