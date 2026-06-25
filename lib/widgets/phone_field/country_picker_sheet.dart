import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'phone_country.dart';

/// Apre un selettore di paese nativo alla piattaforma:
///   - iOS    → `showCupertinoModalPopup` con stile lista iOS + search field
///   - Altrove → `showModalBottomSheet` Material con search bar in alto
///
/// Restituisce il [PhoneCountry] scelto, oppure `null` se l'utente annulla.
///
/// L'utilizzo dei modal nativi al posto della DIALOG di
/// `intl_phone_number_input ^0.7.4` risolve il bug di hit-testing per cui i
/// tap sulle voci della lista venivano sporadicamente ignorati su iOS.
Future<PhoneCountry?> showCountryPicker(BuildContext context) {
  if (Platform.isIOS) {
    return showCupertinoModalPopup<PhoneCountry>(
      context: context,
      builder: (_) => const _CupertinoCountryPicker(),
    );
  }
  return showModalBottomSheet<PhoneCountry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _MaterialCountryPicker(),
  );
}

// ── iOS ─────────────────────────────────────────────────────────────────────

class _CupertinoCountryPicker extends StatefulWidget {
  const _CupertinoCountryPicker();

  @override
  State<_CupertinoCountryPicker> createState() =>
      _CupertinoCountryPickerState();
}

class _CupertinoCountryPickerState extends State<_CupertinoCountryPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PhoneCountry> get _filtered {
    final all = PhoneCountry.all();
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase().trim();
    // Match per nome o per dial code (con o senza "+").
    final qDial = q.startsWith('+') ? q : '+$q';
    return all.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.dial.toLowerCase().contains(qDial) ||
          c.dial.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Altezza ~85% schermata: lascia un po' di sfondo visibile come il modal
    // sheet di sistema iOS.
    final height = media.size.height * 0.85;
    final items = _filtered;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Maniglia top
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey3.resolveFrom(context),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            // Header con titolo + Annulla
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  const SizedBox(width: 60), // bilanciamento col bottone destro
                  Expanded(
                    child: Text(
                      'Seleziona paese',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annulla'),
                    ),
                  ),
                ],
              ),
            ),
            // Search field iOS nativo
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: CupertinoSearchTextField(
                controller: _searchCtrl,
                placeholder: 'Cerca paese o prefisso',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const Divider(height: 0.5, thickness: 0.5),
            // Lista
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'Nessun risultato',
                        style: TextStyle(
                          color:
                              CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 0.5,
                        thickness: 0.5,
                        indent: 56,
                        color: CupertinoColors.separator.resolveFrom(context),
                      ),
                      itemBuilder: (ctx, i) {
                        final c = items[i];
                        return CupertinoListTileLikeButton(
                          country: c,
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tile in stile iOS: bandiera + nome + dial code a destra. Implementato come
/// `CupertinoButton` per avere il feedback opacity nativo.
class CupertinoListTileLikeButton extends StatelessWidget {
  const CupertinoListTileLikeButton(
      {super.key, required this.country, required this.onTap});

  final PhoneCountry country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(country.flagEmoji,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                country.name,
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              country.dial,
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Android / altro ─────────────────────────────────────────────────────────

class _MaterialCountryPicker extends StatefulWidget {
  const _MaterialCountryPicker();

  @override
  State<_MaterialCountryPicker> createState() => _MaterialCountryPickerState();
}

class _MaterialCountryPickerState extends State<_MaterialCountryPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PhoneCountry> get _filtered {
    final all = PhoneCountry.all();
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase().trim();
    final qDial = q.startsWith('+') ? q : '+$q';
    return all.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.dial.toLowerCase().contains(qDial) ||
          c.dial.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final height = media.size.height * 0.85;
    final items = _filtered;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          // Maniglia top
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Seleziona paese',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Cerca paese o prefisso',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Nessun risultato'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final c = items[i];
                      return ListTile(
                        leading: Text(c.flagEmoji,
                            style: const TextStyle(fontSize: 24)),
                        title: Text(c.name),
                        trailing: Text(
                          c.dial,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
