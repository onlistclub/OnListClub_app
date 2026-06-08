import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/orders_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/shared_footer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) => const ProfileScreen();

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with ScreenAnalytics {
  @override
  String get screenName => 'profile';

  final _nomeCtrl = TextEditingController();
  final _cognomeCtrl = TextEditingController();
  final _dataNascitaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  List<Map<String, dynamic>> _preferiti = [];

  // Valori originali per confronto
  String _origNome = '';
  String _origCognome = '';
  String _origDob = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _nomeCtrl.addListener(_checkChanges);
    _cognomeCtrl.addListener(_checkChanges);
    _dataNascitaCtrl.addListener(_checkChanges);
  }

  @override
  void dispose() {
    _nomeCtrl.removeListener(_checkChanges);
    _cognomeCtrl.removeListener(_checkChanges);
    _dataNascitaCtrl.removeListener(_checkChanges);
    _nomeCtrl.dispose();
    _cognomeCtrl.dispose();
    _dataNascitaCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _checkChanges() {
    final changed = _nomeCtrl.text != _origNome ||
        _cognomeCtrl.text != _origCognome ||
        _dataNascitaCtrl.text != _origDob;
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        OrdersService.getUserProfile(),
        OrdersService.getPreferiti(),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final preferiti = results[1] as List<Map<String, dynamic>>;

      if (profile != null) {
        _nomeCtrl.text = profile['nome'] ?? '';
        _cognomeCtrl.text = profile['cognome'] ?? '';
        _emailCtrl.text = profile['email'] ?? Supabase.instance.client.auth.currentUser?.email ?? '';
        final dob = profile['data_nascita'];
        if (dob != null) {
          try {
            final date = DateTime.parse(dob.toString());
            _dataNascitaCtrl.text = DateFormat('dd/MM/yyyy').format(date);
          } catch (_) {
            _dataNascitaCtrl.text = dob.toString();
          }
        }
      }

      // Salva valori originali
      _origNome = _nomeCtrl.text;
      _origCognome = _cognomeCtrl.text;
      _origDob = _dataNascitaCtrl.text;

      setState(() {
        _preferiti = preferiti;
        _isLoading = false;
        _hasChanges = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('[ProfileScreen] Errore caricamento: $e');
    }
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime(2000, 1, 1);
    if (_dataNascitaCtrl.text.isNotEmpty) {
      try {
        initial = DateFormat('dd/MM/yyyy').parse(_dataNascitaCtrl.text);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('it', 'IT'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: OnlistColors.blueElectric,
              onPrimary: OnlistColors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: OnlistColors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _dataNascitaCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_hasChanges) return;
    setState(() => _isSaving = true);
    try {
      String? dataNascitaDb;
      if (_dataNascitaCtrl.text.isNotEmpty) {
        try {
          final date = DateFormat('dd/MM/yyyy').parse(_dataNascitaCtrl.text);
          dataNascitaDb = DateFormat('yyyy-MM-dd').format(date);
        } catch (_) {
          dataNascitaDb = _dataNascitaCtrl.text;
        }
      }

      await OrdersService.updateProfile(
        nome: _nomeCtrl.text.isEmpty ? null : _nomeCtrl.text,
        cognome: _cognomeCtrl.text.isEmpty ? null : _cognomeCtrl.text,
        dataNascita: dataNascitaDb,
      );

      // Aggiorna valori originali
      _origNome = _nomeCtrl.text;
      _origCognome = _cognomeCtrl.text;
      _origDob = _dataNascitaCtrl.text;

      if (mounted) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: OnlistColors.white, size: 20),
                const SizedBox(width: 10),
                Text('Profilo aggiornato!', style: OnlistTextStyles.hn(color: OnlistColors.white)),
              ],
            ),
            backgroundColor: OnlistColors.blueElectric,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e', style: OnlistTextStyles.hn(color: OnlistColors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Determina se l'utente ha già una password (registrazione via email) o se
    // è entrato solo con Google/Apple. Nel secondo caso non c'è una password da
    // verificare: gli si fa "impostare" una nuova password.
    final providers = (user.appMetadata['providers'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final hasPassword = providers.contains('email');
    final email =
        _emailCtrl.text.isNotEmpty ? _emailCtrl.text : (user.email ?? '');

    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ChangePasswordDialog(hasPassword: hasPassword, email: email),
    );

    if (changed == true) {
      // La notifica non è critica: un suo errore non deve mascherare il
      // successo del cambio password.
      try {
        await NotificationService.sendPasswordChangeNotification();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: OnlistColors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  hasPassword ? 'Password aggiornata!' : 'Password impostata!',
                  style: OnlistTextStyles.hn(color: OnlistColors.white),
                ),
              ],
            ),
            backgroundColor: OnlistColors.blueElectric,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Disconnetti', style: OnlistTextStyles.hn(color: OnlistColors.white, fontWeight: FontWeight.bold)),
        content: Text('Sei sicuro di voler uscire dal tuo account?', style: OnlistTextStyles.hn(color: OnlistColors.white.withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla', style: OnlistTextStyles.hn(color: OnlistColors.white.withValues(alpha: 0.54))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Esci', style: OnlistTextStyles.hn(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // La navigazione ad authenticationScreen viene gestita dal listener
      // onAuthStateChange in AuthService.
      await AuthService.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnlistColors.black,
      body: Container(
        decoration: const BoxDecoration(gradient: OnlistColors.screenBackground),
        child: SafeArea(
          child: Column(
            children: [
              // Navbar fissa condivisa (logo + ricerca + persona) — come Figma.
              // Tap "persona" no-op: si è già sulla pagina Account.
              CustomTopBar(onProfileTap: () {}),
              Expanded(
                child: _isLoading
                    ? const AppLoadingIndicator()
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: R.sp(8)),
                            // ── Campi dati personali (sottolineati, stile Figma) ──
                            _buildField(label: 'Nome', controller: _nomeCtrl),
                            _buildField(label: 'Cognome', controller: _cognomeCtrl),
                            _buildField(
                              label: 'Data di nascita',
                              controller: _dataNascitaCtrl,
                              readOnly: true,
                              onTap: _pickDate,
                            ),
                            _buildField(label: 'Email', controller: _emailCtrl, readOnly: true),
                            // Pulsante salva (appare solo se ci sono modifiche)
                            _buildSaveButton(),
                            SizedBox(height: R.sp(24)),
                            // ── Salvati (preferiti) — sezione SEMPRE visibile ──
                            _buildSectionTitle('Salvati'),
                            SizedBox(height: R.sp(8)),
                            if (_preferiti.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'Non hai preferiti',
                                  style: OnlistTextStyles.hn(
                                    fontSize: R.sp(16),
                                    fontWeight: FontWeight.w400,
                                    color: OnlistColors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              )
                            else
                              ..._preferiti.map((p) {
                                final locale = p['locali'] as Map<String, dynamic>?;
                                if (locale == null) return const SizedBox.shrink();
                                return _buildPreferitoCard(locale);
                              }),
                            SizedBox(height: R.sp(20)),
                            // ── Azioni account (mantenute, restyle minimale) ──
                            _buildAccountActions(),
                            SizedBox(height: R.sp(24)),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SharedFooter(currentIndex: -1),
    );
  }

  // ── Campo dato sottolineato: label piccola + valore + linea bianca ──
  Widget _buildField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, R.sp(14), 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: OnlistTextStyles.hn(
              fontSize: R.sp(14),
              fontWeight: FontWeight.w400,
              color: OnlistColors.white.withValues(alpha: 0.6),
            ),
          ),
          TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            style: OnlistTextStyles.hn(
              fontSize: R.sp(16),
              fontWeight: FontWeight.w400,
              color: OnlistColors.white,
            ),
            cursorColor: OnlistColors.white,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.only(top: 6, bottom: 8),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: OnlistColors.white, width: 1),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: OnlistColors.white, width: 1),
              ),
              disabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: OnlistColors.white, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: _hasChanges
          ? Padding(
              padding: EdgeInsets.fromLTRB(24, R.sp(20), 24, 0),
              child: GestureDetector(
                onTap: _isSaving ? null : _saveProfile,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: R.sp(14)),
                  decoration: BoxDecoration(
                    gradient: OnlistColors.primaryCTA,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: OnlistColors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Salva Modifiche',
                          style: OnlistTextStyles.hn(
                            fontSize: R.sp(16),
                            fontWeight: FontWeight.w700,
                            color: OnlistColors.white,
                          ),
                        ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title,
        style: OnlistTextStyles.hn(
          fontSize: R.sp(26),
          fontWeight: FontWeight.w700,
          color: OnlistColors.white,
          letterSpacing: -0.08 * 26,
        ),
      ),
    );
  }

  // ── Azioni account: righe minimali (logica invariata) ──
  Widget _buildAccountActions() {
    return Column(
      children: [
        const Divider(height: 1, color: Colors.white10, indent: 24, endIndent: 24),
        _buildActionTile(
          icon: Icons.receipt_long_outlined,
          label: 'Riepilogo Ordini',
          onTap: () => NavigatorService.pushNamed(AppRoutes.ordersScreen),
        ),
        _buildActionTile(
          icon: Icons.lock_outline,
          label: 'Cambia Password',
          subtitle: 'Aggiorna la tua password',
          onTap: _changePassword,
        ),
        _buildActionTile(
          icon: Icons.logout,
          label: 'Disconnetti',
          color: Colors.redAccent,
          onTap: _confirmLogout,
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    String? subtitle,
    Color color = OnlistColors.white,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: R.sp(14)),
        child: Row(
          children: [
            Icon(icon, color: color == OnlistColors.white ? OnlistColors.blueElectric : color, size: R.sp(22)),
            SizedBox(width: R.sp(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: OnlistTextStyles.hn(fontSize: R.sp(16), fontWeight: FontWeight.w400, color: color)),
                  if (subtitle != null)
                    Text(subtitle, style: OnlistTextStyles.hn(fontSize: R.sp(12), fontWeight: FontWeight.w400, color: OnlistColors.white.withValues(alpha: 0.4))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.4), size: R.sp(20)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferitoCard(Map<String, dynamic> locale) {
    final nome = locale['nome'] ?? '';
    final fotoUrl = locale['foto_url'] as String?;

    return GestureDetector(
      onTap: () => NavigatorService.pushNamed(
        AppRoutes.clubDetailScreen,
        arguments: {'id': locale['id']},
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF1A1A1A),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (fotoUrl != null)
                CachedNetworkImage(
                  imageUrl: fotoUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xFF1A1A1A)),
                )
              else
                Container(color: const Color(0xFF1A1A1A)),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 14,
                child: Text(
                  nome,
                  style: OnlistTextStyles.hn(
                    fontSize: R.sp(24),
                    fontWeight: FontWeight.w700,
                    color: OnlistColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog di cambio password in-app.
///
/// Per gli utenti registrati via email (`hasPassword == true`) chiede la
/// password attuale e la verifica con un re-login prima di aggiornarla
/// (Supabase non espone un check diretto della password). Per gli utenti
/// OAuth (Google/Apple) senza password, consente di impostarne una nuova così
/// da poter accedere anche con email. Pop con `true` solo se l'aggiornamento
/// va a buon fine.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.hasPassword, required this.email});

  final bool hasPassword;
  final String email;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final newPwd = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (widget.hasPassword && current.isEmpty) {
      setState(() => _error = 'Inserisci la password attuale');
      return;
    }
    if (newPwd.length < 8) {
      setState(() => _error = 'La nuova password deve avere almeno 8 caratteri');
      return;
    }
    if (newPwd != confirm) {
      setState(() => _error = 'Le password non coincidono');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final client = Supabase.instance.client;
    try {
      // Verifica della password attuale via re-login: se le credenziali sono
      // sbagliate signInWithPassword lancia AuthException.
      if (widget.hasPassword) {
        try {
          await client.auth.signInWithPassword(
            email: widget.email,
            password: current,
          );
        } on AuthException {
          setState(() {
            _isSaving = false;
            _error = 'Password attuale errata';
          });
          return;
        }
      }

      await client.auth.updateUser(UserAttributes(password: newPwd));
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      setState(() {
        _isSaving = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = 'Errore: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        widget.hasPassword ? 'Cambia Password' : 'Imposta Password',
        style: OnlistTextStyles.hn(
            color: OnlistColors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.hasPassword)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Hai effettuato l\'accesso con Google o Apple. Imposta una '
                'password per poter accedere anche con email.',
                style: OnlistTextStyles.hn(
                  color: OnlistColors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ),
          if (widget.hasPassword) ...[
            _field(
              controller: _currentCtrl,
              hint: 'Password attuale',
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 12),
          ],
          _field(
            controller: _newCtrl,
            hint: 'Nuova password',
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
          ),
          const SizedBox(height: 12),
          _field(
            controller: _confirmCtrl,
            hint: 'Conferma nuova password',
            obscure: _obscureNew,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: OnlistTextStyles.hn(color: Colors.redAccent, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: Text('Annulla',
              style: OnlistTextStyles.hn(
                  color: OnlistColors.white.withValues(alpha: 0.54))),
        ),
        TextButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      color: OnlistColors.blueElectric, strokeWidth: 2),
                )
              : Text('Salva',
                  style: OnlistTextStyles.hn(
                      color: OnlistColors.blueElectric,
                      fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    VoidCallback? onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: OnlistTextStyles.hn(color: OnlistColors.white, fontSize: 15),
      cursorColor: OnlistColors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: OnlistTextStyles.hn(
            color: OnlistColors.white.withValues(alpha: 0.4), fontSize: 15),
        isDense: true,
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: OnlistColors.blueElectric)),
        suffixIcon: onToggle == null
            ? null
            : IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white54, size: 20),
                onPressed: onToggle,
              ),
      ),
    );
  }
}
