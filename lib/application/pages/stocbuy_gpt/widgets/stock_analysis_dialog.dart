import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/models/stock_search_result.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/search_stocks.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/utils/stock_symbol_util.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// Returns the chosen plain symbol (e.g. `tcs`) or null if cancelled.
Future<String?> showStockAnalysisDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => const _StockAnalysisDialog(),
  );
}

class _StockAnalysisDialog extends StatefulWidget {
  const _StockAnalysisDialog();

  @override
  State<_StockAnalysisDialog> createState() => _StockAnalysisDialogState();
}

class _StockAnalysisDialogState extends State<_StockAnalysisDialog> {
  final _symbolCtrl = TextEditingController();
  final _searchDio = SearchStocksDio();
  Timer? _debounce;
  List<StockSearchResult> _suggestions = [];
  bool _searching = false;
  String? _error;
  String? _authHint;

  @override
  void dispose() {
    _debounce?.cancel();
    _symbolCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _suggestions = [];
        _searching = false;
        _authHint = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), () => _fetch(q));
  }

  Future<void> _fetch(String query) async {
    setState(() {
      _searching = true;
      _authHint = null;
    });
    try {
      final list = await _searchDio.searchStocks(query);
      if (!mounted) return;
      setState(() {
        _suggestions = list;
        _searching = false;
      });
    } on SearchAuthRequiredException {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _searching = false;
        _authHint = 'Sign in to see stock suggestions.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _searching = false;
      });
    }
  }

  void _pick(StockSearchResult item) {
    final symbol = displayStockSymbol(item.symbol);
    _symbolCtrl.text = symbol;
    setState(() {
      _suggestions = [];
      _error = null;
    });
  }

  void _done() {
    final symbol = normalizeStockSymbol(_symbolCtrl.text);
    if (symbol.isEmpty) {
      setState(() => _error = 'Enter or select a stock symbol (e.g. TCS).');
      return;
    }
    Navigator.of(context).pop(symbol);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final dialogW = w < 400 ? w - 32.0 : 420.0;

    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogW),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stock analysis',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.darkblue,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.grey,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Search and select a stock. Then type your question in the chat '
                'and press send.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.grey.withValues(alpha: 0.95),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _symbolCtrl,
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  labelText: 'Stock symbol',
                  hintText: 'Search TCS, INFY, RELIANCE…',
                  errorText: _error,
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.search_rounded, size: 22),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.lightblue,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) => _done(),
              ),
              if (_authHint != null) ...[
                const SizedBox(height: 8),
                Text(
                  _authHint!,
                  style: TextStyle(fontSize: 12, color: AppColors.grey),
                ),
              ],
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.white,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: AppColors.border.withValues(alpha: 0.8),
                      ),
                      itemBuilder: (context, i) {
                        final item = _suggestions[i];
                        final sym = displayStockSymbol(item.symbol);
                        return ListTile(
                          dense: true,
                          title: Text(
                            sym,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            item.displaySubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => _pick(item),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _done,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lightblue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
