def clean_financial_data(df):
    if df is None or df.empty:
        return None

    # Convert rows → columns (dates become rows)
    df = df.T

    # Remove columns where all values are NaN
    df = df.dropna(axis=1, how='all')

    # Fill remaining NaN with 0
    df = df.fillna(0)

    result = []
    for date, row in df.iterrows():
        entry = {"date": str(date)[:10]}  # Format: 2024-03-31
        entry.update(row.to_dict())
        result.append(entry)

    return result