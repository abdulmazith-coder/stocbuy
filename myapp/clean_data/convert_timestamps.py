import numpy as np
import pandas as pd

def convert_timestamps(obj):
    """Recursively convert Timestamp keys/values to strings."""
    if isinstance(obj, dict):
        return {
            (k.strftime('%Y-%m-%d') if hasattr(k, 'strftime') else k): convert_timestamps(v)
            for k, v in obj.items()
        }
    elif isinstance(obj, list):
        return [convert_timestamps(i) for i in obj]
    elif hasattr(obj, 'strftime'):  # Handles Timestamp values too
        return obj.strftime('%Y-%m-%d')
    return obj