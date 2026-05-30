import json
import yfinance as yf

from yfinance import EquityQuery
from django.http import StreamingHttpResponse
from django.core.cache import cache

from myapp.datasource.screener.filter_stocks import FilterStocks


# =========================================
# CAP TYPE CONFIGURATIONS
# Switch between penny / mid / large
# by passing cap_type to get_all_stocks()
# =========================================
CAP_CONFIGS = {

    # =========================================================
    # PENNY STOCKS
    # High risk + high growth potential
    # =========================================================
    'penny': {
        'label': 'Penny Growth',

        # Better realistic Indian penny stock price ranges
        'price_bands': [
            (5, 15),
            (15, 30),
            (30, 60),
            (60, 100),
        ],

        # Small market cap companies
        'min_mcap': 100_000_000,       # ₹10 Cr
        'max_mcap': 20_000_000_000,    # ₹2000 Cr

        # Liquidity filters
        'min_volume': 50_000,
        'min_avg_volume': 100_000,

        # Financial quality filters
        'min_revenue_growth': 10,      # %
        'min_profit_growth': 5,        # %
        'min_roe': 8,                  # %
        'max_debt_to_equity': 1.5,

        # Momentum filters
        'min_price_change_6m': 5,      # %
        'min_price_change_1y': 10,     # %

        # Risk filters
        'avoid_loss_making': True,
        'avoid_operator_stocks': True,

        # Cache
        'cache_key': 'screener_seen_penny',
        'run_key': 'screener_run_penny',
    },

    # =========================================================
    # MID CAP STOCKS
    # Balance between growth + safety
    # =========================================================
    'mid': {
        'label': 'Mid Cap Growth',

        'price_bands': [
            (100, 300),
            (300, 700),
            (700, 1500),
            (1500, 3000),
        ],

        # ₹5,000 Cr to ₹50,000 Cr
        'min_mcap': 50_000_000_000,
        'max_mcap': 500_000_000_000,

        'min_volume': 100_000,
        'min_avg_volume': 200_000,

        # Strong growth filters
        'min_revenue_growth': 12,
        'min_profit_growth': 10,
        'min_roe': 12,
        'max_debt_to_equity': 1.0,

        # Institutional quality
        'min_promoter_holding': 40,
        'max_pledge_percent': 5,

        # Momentum
        'min_price_change_6m': 10,
        'min_price_change_1y': 15,

        'avoid_loss_making': True,

        'cache_key': 'screener_seen_mid',
        'run_key': 'screener_run_mid',
    },

    # =========================================================
    # LARGE CAP STOCKS
    # Stable + safer growth
    # =========================================================
    'large': {
        'label': 'Large Cap Compounders',

        'price_bands': [
            (300, 1000),
            (1000, 2500),
            (2500, 5000),
            (5000, 20000),
        ],

        # > ₹50,000 Cr
        'min_mcap': 500_000_000_000,
        'max_mcap': None,

        'min_volume': 200_000,
        'min_avg_volume': 500_000,

        # Strong fundamentals
        'min_revenue_growth': 8,
        'min_profit_growth': 8,
        'min_roe': 15,
        'max_debt_to_equity': 0.7,

        # Safer companies
        'min_promoter_holding': 45,
        'max_pledge_percent': 2,

        # Momentum
        'min_price_change_6m': 5,
        'min_price_change_1y': 10,

        'avoid_loss_making': True,

        'cache_key': 'screener_seen_large',
        'run_key': 'screener_run_large',
    },

    # =========================================================
    # HIGH GROWTH STOCKS
    # Fast growing companies
    # =========================================================
    'growth': {
        'label': 'High Growth Stocks',

        'price_bands': [
            (50, 300),
            (300, 1000),
            (1000, 3000),
            (3000, 10000),
        ],

        # Any size company allowed
        'min_mcap': 2_000_000_000,       # ₹200 Cr
        'max_mcap': None,

        'min_volume': 100_000,
        'min_avg_volume': 200_000,

        # Aggressive growth filters
        'min_revenue_growth': 20,
        'min_profit_growth': 20,
        'min_roe': 15,
        'max_debt_to_equity': 0.8,

        # Quality checks
        'min_promoter_holding': 35,
        'max_pledge_percent': 5,

        # Strong momentum
        'min_price_change_6m': 15,
        'min_price_change_1y': 25,

        'avoid_loss_making': True,

        'cache_key': 'screener_seen_growth',
        'run_key': 'screener_run_growth',
    },
}

SORT_FIELDS = [
    'dayvolume',
    'intradaymarketcap',
    'intradayprice',
    'percentchange',
]

BATCH_SIZE = 250


class GetGoodStock:

    def fetch_stocks(self, low, high, config, sort_field,exchange='BSE'):

        filters = [
            EquityQuery('eq', ['exchange', exchange]),
            EquityQuery('gt', ['intradayprice', low]),
            EquityQuery('lt', ['intradayprice', high]),
            EquityQuery('gt', ['dayvolume', config['min_volume']]),
        ]

        # Add marketcap filters if defined for this cap type
        if config['min_mcap']:
            filters.append(EquityQuery('gt', ['intradaymarketcap', config['min_mcap']]))
        if config['max_mcap']:
            filters.append(EquityQuery('lt', ['intradaymarketcap', config['max_mcap']]))

        query = EquityQuery('and', filters)
        results = []

        for offset in range(0, 500, BATCH_SIZE):
            try:
                response = yf.screen(
                    query,
                    size=BATCH_SIZE,
                    offset=offset,
                    sortField=sort_field,
                    sortAsc=False
                )
                batch = response.get('quotes', [])
                if not batch:
                    break
                results.extend(batch)
                if len(batch) < BATCH_SIZE:
                    break
            except Exception as e:
                print(f"fetch_stocks error [{low}-{high}]: {e}")
                break

        return results

    def get_all_stocks(self, cap_type='penny',exchange='BSE'):

        # Default to penny if unknown cap_type passed
        config = CAP_CONFIGS.get(cap_type, CAP_CONFIGS['penny'])

        def event_stream():

            try:

                yield f"data: {json.dumps({'type': 'info', 'message': f'Starting {config['label']} scanner'})}\n\n"

                # Rotate sort field per run
                seen_symbols = cache.get(config['cache_key'], set())
                run_count    = cache.get(config['run_key'], 0)
                sort_field   = SORT_FIELDS[run_count % len(SORT_FIELDS)]
                cache.set(config['run_key'], run_count + 1, timeout=None)

                yield f"data: {json.dumps({'type': 'info', 'message': f'Sort: {sort_field} | Run #{run_count + 1} | Already seen: {len(seen_symbols)}'})}\n\n"

                # STEP 1: FETCH
                all_stocks = []
                for (low, high) in config['price_bands']:
                    yield f"data: {json.dumps({'type': 'info', 'message': f'Fetching ₹{low}-₹{high}'})}\n\n"
                    stocks = self.fetch_stocks(low, high, config, sort_field,exchange)
                    yield f"data: {json.dumps({'type': 'info', 'message': f'Got {len(stocks)} in ₹{low}-₹{high}'})}\n\n"
                    all_stocks.extend(stocks)

                # STEP 2: DEDUPLICATE THIS RUN
                seen_this_run = set()
                unique_stocks = [
                    s for s in all_stocks
                    if not (s['symbol'] in seen_this_run or seen_this_run.add(s['symbol']))
                ]

                # STEP 3: SKIP ALREADY SEEN
                new_stocks = [s for s in unique_stocks if s['symbol'] not in seen_symbols]
                skipped    = len(unique_stocks) - len(new_stocks)

                yield f"data: {json.dumps({'type': 'info', 'message': f'Unique: {len(unique_stocks)} | Skipped: {skipped} | New: {len(new_stocks)}'})}\n\n"

                # if not new_stocks:
                #     cache.delete(config['cache_key'])
                #     cache.delete(config['run_key'])
                #     yield f"data: {json.dumps({'type': 'completed', 'message': 'All seen. Cache reset.', 'total_good_stocks': 0, 'good_stocks': []})}\n\n"
                #     return

                # STEP 4: MARK AS SEEN
                seen_symbols.update([s['symbol'] for s in new_stocks])
                # cache.set(config['cache_key'], seen_symbols, timeout=None)

                # STEP 5: FILTER + SCORE
                filter_obj = FilterStocks()
                for update in filter_obj.filter_penny_stocks(new_stocks):
                    yield f"data: {json.dumps(update)}\n\n"

            except Exception as e:
                yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

        return StreamingHttpResponse(event_stream(), content_type="text/event-stream")