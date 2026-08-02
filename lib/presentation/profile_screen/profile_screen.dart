import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/account_deletion_service.dart';
import '../../core/services/auth_service.dart';
// NOTIFICHE DISATTIVATE (MVP): usato solo dalla voce notifiche commentata.
// import '../../core/services/badge_service.dart';
import '../../core/services/orders_service.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/custom_top_bar.dart';
import '../../widgets/dashed_line.dart';
import '../../widgets/glow_card.dart';
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

  // Dati del pannello Account (design NUOVO): telefono da
  // `utenti_numeri_telefono`, conteggio serate e foto profilo.
  String? _telefono;
  int _numeroSerate = 0;
  String? _fotoUrl;
  bool _isUploadingFoto = false;

  // Cache in memoria condivisa tra le aperture: riaprendo il Profilo si mostrano
  // subito gli ultimi dati (niente spinner), mentre un refresh silenzioso in
  // background li aggiorna. Aggiornata anche al salvataggio del profilo.
  static Map<String, dynamic>? _cachedProfile;
  static List<Map<String, dynamic>>? _cachedPreferiti;

  // Valori originali per confronto
  String _origNome = '';
  String _origCognome = '';
  String _origDob = '';

  @override
  void initState() {
    super.initState();
    if (_cachedProfile != null || _cachedPreferiti != null) {
      // Riapertura: popola subito dai dati in cache (nessuno spinner) e
      // aggiorna in background senza far ricomparire il loader.
      _applyControllers(_cachedProfile);
      _preferiti = _cachedPreferiti ?? _preferiti;
      _fotoUrl = _cachedProfile?['foto_url'] as String?;
      _isLoading = false;
      _loadData(silent: true);
    } else {
      _loadData();
    }
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

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        OrdersService.getUserProfile(),
        OrdersService.getPreferiti(),
        OrdersService.getUserTelefono(),
        OrdersService.getNumeroSerate(),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final preferiti = results[1] as List<Map<String, dynamic>>;
      _telefono = results[2] as String?;
      _numeroSerate = results[3] as int;
      _fotoUrl = profile?['foto_url'] as String?;

      _cachedProfile = profile;
      _cachedPreferiti = preferiti;
      if (!mounted) return;

      // In refresh silenzioso NON sovrascrivere i campi se l'utente li sta
      // modificando in quel momento.
      final bool updateFields = !silent || !_hasChanges;
      if (updateFields) _applyControllers(profile);

      setState(() {
        _preferiti = preferiti;
        _isLoading = false;
        if (updateFields) _hasChanges = false;
      });
      // Tempo di caricamento: solo al primo load reale (non sui refresh cache).
      if (!silent) reportLoadTime('load_time_profilo');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // Registra l'errore di caricamento profilo per la TAB Errori.
      AnalyticsService.reportError(e, screen: 'profile');
      debugPrint('[ProfileScreen] Errore caricamento: $e');
    }
  }

  /// Popola i controller e i valori "originali" dal profilo (fetch o cache).
  /// Da chiamare FUORI da setState: muta i controller, che notificano da soli.
  void _applyControllers(Map<String, dynamic>? profile) {
    if (profile == null) return;
    _nomeCtrl.text = profile['nome'] ?? '';
    _cognomeCtrl.text = profile['cognome'] ?? '';
    _emailCtrl.text = profile['email'] ??
        Supabase.instance.client.auth.currentUser?.email ??
        '';
    final dob = profile['data_nascita'];
    if (dob != null) {
      try {
        final date = DateTime.parse(dob.toString());
        _dataNascitaCtrl.text = DateFormat('dd/MM/yyyy').format(date);
      } catch (_) {
        _dataNascitaCtrl.text = dob.toString();
      }
    }
    // Baseline per _checkChanges.
    _origNome = _nomeCtrl.text;
    _origCognome = _cognomeCtrl.text;
    _origDob = _dataNascitaCtrl.text;
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
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1A1A1A)),
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
    // `_isSaving` fa anche da guardia: il dialog di modifica può essere
    // riaperto e confermato più volte, il salvataggio parte una sola volta.
    if (!_hasChanges || _isSaving) return;
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

      // Allinea la cache così la prossima apertura mostra subito i valori salvati.
      _cachedProfile = {
        ...?_cachedProfile,
        'nome': _nomeCtrl.text,
        'cognome': _cognomeCtrl.text,
        'data_nascita': dataNascitaDb,
      };

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
      if (mounted) showAppErrorDialog(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Avvia il flusso di cambio password via email.
  ///
  /// Il cambio avviene fuori dall'app: Supabase invia un'email con un link
  /// (template "Reset Password" in dashboard) che porta a
  /// https://www.onlistclub.com/reset-password dove l'utente imposta la
  /// nuova password. Funziona anche per gli utenti OAuth (Google/Apple) che
  /// non hanno mai impostato una password: in quel caso ne creano una.
  Future<void> _changePassword() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final email =
        _emailCtrl.text.isNotEmpty ? _emailCtrl.text : (user.email ?? '');
    if (email.isEmpty) {
      if (mounted) showAppErrorDialog(context, 'Email non disponibile.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Cambia Password',
          style: OnlistTextStyles.hn(
              color: OnlistColors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Ti invieremo un\'email a $email con un link per impostare una nuova password.',
          style: OnlistTextStyles.hn(
            color: OnlistColors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla',
                style: OnlistTextStyles.hn(
                    color: OnlistColors.white.withValues(alpha: 0.54))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Invia email',
                style: OnlistTextStyles.hn(
                    color: OnlistColors.blueElectric,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://www.onlistclub.com/reset-password',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined,
                    color: OnlistColors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Email inviata. Controlla la tua casella di posta.',
                    style: OnlistTextStyles.hn(color: OnlistColors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: OnlistColors.blueElectric,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) showAppErrorDialog(context, 'Errore: $e');
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
            child: Text('Esci', style: OnlistTextStyles.hn(color: OnlistColors.destructive, fontWeight: FontWeight.bold)),
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

  /// Avvia la cancellazione account: conferma, poi richiesta dell'email col
  /// link. Qui non si cancella nulla — il punto di non ritorno è sul sito.
  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Elimina account',
            style: OnlistTextStyles.hn(
                color: OnlistColors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Ti invieremo un\'email con un link per completare la '
          'cancellazione.\n\nL\'operazione è definitiva: i tuoi dati personali '
          'verranno rimossi e perderai l\'accesso ai ticket già acquistati.',
          style:
              OnlistTextStyles.hn(color: OnlistColors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla',
                style: OnlistTextStyles.hn(
                    color: OnlistColors.white.withValues(alpha: 0.54))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Invia email',
                style: OnlistTextStyles.hn(
                    color: OnlistColors.destructive, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await AccountDeletionService.requestDeletion();
    if (!mounted) return;

    if (!res.ok) {
      showAppErrorDialog(context, _deletionErrorMessage(res.error));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.mark_email_read_outlined,
                color: OnlistColors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Email inviata. Apri il link per completare la cancellazione.',
                style: OnlistTextStyles.hn(color: OnlistColors.white),
              ),
            ),
          ],
        ),
        backgroundColor: OnlistColors.blueElectric,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Messaggio d'errore in base allo stadio fallito (vedi
  /// [AccountDeletionService.requestDeletion]). Il codice tecnico resta tra
  /// parentesi per diagnosticare al volo senza aprire i log.
  String _deletionErrorMessage(String? code) {
    switch (code) {
      case 'unauthorized':
        return 'Sessione scaduta. Esci e rientra, poi riprova.';
      case 'no_email':
        return 'Il tuo account non ha un\'email associata: non c\'è dove '
            'inviare il link di conferma.';
      case 'db_error':
        return 'Errore del server nel registrare la richiesta. Riprova più '
            'tardi. (db_error)';
      case 'email_error':
        return 'Richiesta registrata, ma l\'invio dell\'email è fallito. '
            'Riprova tra poco. (email_error)';
      case 'unexpected':
        return 'Errore imprevisto del server. Riprova più tardi.';
      default:
        return code == null
            ? 'Non siamo riusciti a inviare l\'email. Riprova tra poco.'
            : 'Non siamo riusciti a inviare l\'email. Riprova tra poco. ($code)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Design NUOVO: sfondo NERO FISSO.
      backgroundColor: OnlistColors.black,
      // Footer flottante: il contenuto scorre dietro la capsula (non la oscura).
      extendBody: true,
      body: ColoredBox(
        color: OnlistColors.black,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Navbar fissa condivisa (logo + ricerca + persona) — come Figma.
              // Tap "persona" no-op: si è già sulla pagina Account.
              CustomTopBar(onProfileTap: () {}),
              _buildBackRow(),
              Expanded(
                child: _isLoading
                    ? const AppLoadingIndicator()
                    : SingleChildScrollView(
                        padding: EdgeInsets.only(bottom: SharedFooter.height),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Pannello blu con foto profilo sovrapposta.
                            _buildProfilePanel(),
                            SizedBox(height: R.sp(20)),
                            // ── Azioni account (invariate) ──
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
      // Footer: unica e globale, montata da RootShell (non qui).
    );
  }

  Widget _buildBackRow() {
    return GestureDetector(
      onTap: () => NavigatorService.goBack(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Row(
          children: [
            const Icon(Icons.arrow_back, color: OnlistColors.white, size: 28),
            const SizedBox(width: 6),
            Text('Torna indietro', style: OnlistTextStyles.title32Light),
          ],
        ),
      ),
    );
  }

  // ── Pannello Account (CSS NUOVO Rectangle 105: 393 full-width, r32,
  //    gradiente ticket + glow ciano) con la foto profilo che lo scavalca.
  Widget _buildProfilePanel() {
    final nomeCompleto =
        '${_nomeCtrl.text} ${_cognomeCtrl.text}'.trim();
    // Foto 114×120 a top 157, pannello a top 243 → sporge di 86.
    const double fotoH = 120;
    const double overlap = 86;

    return Padding(
      padding: EdgeInsets.only(top: R.sp(14)),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: EdgeInsets.only(top: R.sp(overlap)),
            child: SizedBox(
              width: double.infinity,
              child: GlowCard(
                gradient: OnlistColors.ticketCard,
                radius: R.sp(32),
                glowColor: OnlistColors.ticketCardGlow,
                glowSigma: R.sp(50), // inset 0 2px 100px
                glowOffset: Offset(0, R.sp(2)),
                child: Column(
                  children: [
                    // Spazio per la parte di foto che entra nel pannello.
                    SizedBox(height: R.sp(fotoH - overlap + 10)),
                    // Nome e cognome 64/500 centrato (tap → modifica).
                    GestureDetector(
                      onTap: _showEditDialog,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: R.sp(19)),
                        child: SizedBox(
                          height: R.sp(63),
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              nomeCompleto.isEmpty ? 'Il tuo nome' : nomeCompleto,
                              style: OnlistTextStyles.hn(
                                fontSize: R.sp(64),
                                fontWeight: FontWeight.w700,
                                color: OnlistColors.white,
                                height: 63 / 64,
                                letterSpacing: -0.1 * 64,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: R.sp(10)),
                    // Data di nascita 32/500 centrata (tap → modifica).
                    GestureDetector(
                      onTap: _showEditDialog,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        _dataNascitaCtrl.text.isEmpty
                            ? 'Data di nascita'
                            : _dataNascitaCtrl.text,
                        style: OnlistTextStyles.hn(
                          fontSize: R.sp(32),
                          fontWeight: FontWeight.w500,
                          color: OnlistColors.white,
                          height: 32 / 32,
                        ),
                      ),
                    ),
                    SizedBox(height: R.sp(24)),
                    // Telefono (sx) + email (dx), 20/500.
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: R.sp(19)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _telefono ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: OnlistTextStyles.hn(
                                fontSize: R.sp(20),
                                fontWeight: FontWeight.w500,
                                color: OnlistColors.white,
                                height: 20 / 20,
                              ),
                            ),
                          ),
                          SizedBox(width: R.sp(12)),
                          Flexible(
                            child: Text(
                              _emailCtrl.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: OnlistTextStyles.hn(
                                fontSize: R.sp(20),
                                fontWeight: FontWeight.w500,
                                color: OnlistColors.white,
                                height: 20 / 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: R.sp(20)),
                    const DashedLine(widthDesign: 278),
                    SizedBox(height: R.sp(24)),
                    _buildTuEOnlistCard(),
                    SizedBox(height: R.sp(10)),
                    _buildClubSalvatiPill(),
                    SizedBox(height: R.sp(24)),
                    ..._buildPreferitiCards(),
                    SizedBox(height: R.sp(24)),
                  ],
                ),
              ),
            ),
          ),
          // Foto profilo 114×120 r32 con velo scuro e icona fotocamera.
          _buildFotoProfilo(),
        ],
      ),
    );
  }

  Widget _buildFotoProfilo() {
    return GestureDetector(
      onTap: _isUploadingFoto ? null : _pickFotoProfilo,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: R.sp(114),
        height: R.sp(120),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(R.sp(32)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_fotoUrl != null)
              CachedNetworkImage(
                imageUrl: _fotoUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF1A1A1A)),
              ),
            // Velo nero 80% come da CSS (la foto resta leggibile sotto l'icona).
            const ColoredBox(color: Color(0xCC000000)),
            Center(
              child: _isUploadingFoto
                  ? SizedBox(
                      width: R.sp(24),
                      height: R.sp(24),
                      child: const CircularProgressIndicator(
                          color: OnlistColors.white, strokeWidth: 2),
                    )
                  : Icon(Icons.photo_camera_outlined,
                      color: OnlistColors.white, size: R.sp(44)),
            ),
          ],
        ),
      ),
    );
  }

  // Card "Tu e OnList" (CSS Rectangle 44: 357×126 r8, viola #7300FF).
  Widget _buildTuEOnlistCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: R.sp(18)),
      child: Container(
        height: R.sp(126),
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF7300FF),
          borderRadius: BorderRadius.circular(R.sp(8)),
        ),
        child: Stack(
          children: [
            // Disco-ball decorativa a destra (cerchio sfumato bianco).
            Positioned(
              right: R.sp(20),
              top: R.sp(21),
              child: Container(
                width: R.sp(83),
                height: R.sp(83),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      OnlistColors.white.withValues(alpha: 0.85),
                      OnlistColors.white.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(R.sp(22), R.sp(27), 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu e OnList',
                    style: OnlistTextStyles.hn(
                      fontSize: R.sp(20),
                      fontWeight: FontWeight.w500,
                      color: OnlistColors.white,
                      height: 20 / 20,
                    ),
                  ),
                  SizedBox(height: R.sp(9)),
                  Text(
                    '$_numeroSerate ${_numeroSerate == 1 ? 'serata' : 'serate'}',
                    style: OnlistTextStyles.hn(
                      fontSize: R.sp(32),
                      fontWeight: FontWeight.w700,
                      color: OnlistColors.white,
                      height: 32 / 32,
                    ),
                  ),
                  SizedBox(height: R.sp(9)),
                  Text(
                    'da quando ti sei unito al club',
                    style: OnlistTextStyles.hn(
                      fontSize: R.sp(12),
                      fontWeight: FontWeight.w500,
                      color: OnlistColors.white,
                      height: 12 / 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pill "Club salvati" (CSS Rectangle 295: 182×33 r13, bianco 20%).
  Widget _buildClubSalvatiPill() {
    return Center(
      child: Container(
        width: R.sp(182),
        height: R.sp(33),
        decoration: BoxDecoration(
          color: const Color(0x33D9D9D9),
          borderRadius: BorderRadius.circular(R.sp(13)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Club salvati',
              style: OnlistTextStyles.hn(
                fontSize: R.sp(28),
                fontWeight: FontWeight.w400,
                color: OnlistColors.white,
                height: 28 / 28,
                letterSpacing: -0.06 * 28,
              ),
            ),
            SizedBox(width: R.sp(8)),
            Icon(Icons.bookmark, color: OnlistColors.white, size: R.sp(22)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPreferitiCards() {
    if (_preferiti.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: R.sp(18)),
          child: Text(
            'Non hai club salvati',
            style: OnlistTextStyles.hn(
              fontSize: R.sp(16),
              fontWeight: FontWeight.w400,
              color: OnlistColors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ];
    }
    return _preferiti.map((p) {
      final locale = p['locali'] as Map<String, dynamic>?;
      if (locale == null) return const SizedBox.shrink();
      return _buildPreferitoCard(locale);
    }).toList();
  }

  /// Dialog di modifica dati (il pannello mostra solo testo, come da design).
  Future<void> _showEditDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Modifica dati',
              style: OnlistTextStyles.hn(
                  color: OnlistColors.white, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField('Nome', _nomeCtrl),
              _dialogField('Cognome', _cognomeCtrl),
              _dialogField(
                'Data di nascita',
                _dataNascitaCtrl,
                readOnly: true,
                onTap: () async {
                  await _pickDate();
                  setLocal(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla',
                  style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _saveProfile();
                if (mounted) setState(() {});
              },
              child: Text('Salva',
                  style: OnlistTextStyles.hn(
                      color: OnlistColors.blueElectric,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController controller,
      {bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        style: OnlistTextStyles.hn(color: OnlistColors.white),
        cursorColor: OnlistColors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: OnlistTextStyles.hn(color: Colors.white54),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: OnlistColors.white, width: 1),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: OnlistColors.white, width: 1),
          ),
        ),
      ),
    );
  }

  /// Selezione e upload della foto profilo (bucket Storage `avatars`).
  /// Richiede la migration `2026-08-01_foto_profilo_utenti.sql`.
  Future<void> _pickFotoProfilo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _isUploadingFoto = true);
      final url = await OrdersService.uploadFotoProfilo(File(picked.path));
      _cachedProfile = {...?_cachedProfile, 'foto_url': url};
      if (!mounted) return;
      setState(() {
        _fotoUrl = url;
        _isUploadingFoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingFoto = false);
      showAppErrorDialog(context,
          'Impossibile aggiornare la foto profilo.\n$e');
    }
  }

  // ── Azioni account ──────────────────────────────────────────────────────
  // Il Figma dell'Account copre solo la parte alta ("Account aggiornato ma solo
  // parte sopra"): per queste righe non esistono valori CSS. Stile derivato dai
  // token del design system — raggio 10 (standard), margine 18 (come le card
  // club salvati), fondo/bordo nella stessa famiglia della pill "Club salvati"
  // (rgba(217,217,217,.2) attenuato perché qui copre 4 righe su nero).
  static const double _actionRowHeight = 56; // uguale per TUTTE le righe
  static const double _actionRowIndent = 52; // 16 padding + 22 icona + 14 gap

  Widget _buildAccountActions() {
    // NOTIFICHE DISATTIVATE (MVP): la pagina notifiche non deve essere
    // visibile per ora. Voce commentata — riattivare in futuro insieme a
    // `_buildNotificationsTile()`, al badge in `custom_top_bar.dart` e alla
    // route `notificationsScreen` in `app_routes.dart`.
    final tiles = <Widget>[
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
        color: OnlistColors.destructive,
        onTap: _confirmLogout,
      ),
      // Richiesto da Apple (App Store Review 5.1.1(v)): la cancellazione
      // dell'account deve poter partire dall'app. Qui parte; si completa sul
      // sito, dopo il link inviato per email.
      _buildActionTile(
        icon: Icons.delete_forever_outlined,
        label: 'Elimina account',
        subtitle: 'Cancella definitivamente i tuoi dati',
        color: OnlistColors.destructive,
        onTap: _confirmDeleteAccount,
      ),
    ];

    // Separatore 1px allineato al testo (non sotto l'icona): è il dettaglio che
    // fa leggere le righe come un gruppo disegnato e non come ListTile sciolte.
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        rows.add(Padding(
          padding: EdgeInsets.only(left: R.sp(_actionRowIndent)),
          child: Container(height: 1, color: OnlistColors.white.withValues(alpha: 0.08)),
        ));
      }
      rows.add(tiles[i]);
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: R.sp(18)),
      decoration: BoxDecoration(
        color: OnlistColors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(R.sp(10)),
        border: Border.all(
          color: OnlistColors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      // Clippa il ripple del tap agli angoli arrotondati del blocco.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(R.sp(10)),
        child: Column(children: rows),
      ),
    );
  }

  // Riga "Notifiche": stesso stile delle altre azioni account, ma con badge
  // live dal contatore non lette (spostato qui dalla footer).
  // NOTIFICHE DISATTIVATE (MVP): metodo commentato per nascondere la pagina
  // notifiche. Riattivare insieme alla chiamata in `_buildAccountActions()`.
  /*
  Widget _buildNotificationsTile() {
    return InkWell(
      onTap: () {
        BadgeService().clearNotificationBadge();
        NavigatorService.pushNamed(AppRoutes.notificationsScreen);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: R.sp(14)),
        child: Row(
          children: [
            Icon(Icons.notifications_outlined,
                color: OnlistColors.blueElectric, size: R.sp(22)),
            SizedBox(width: R.sp(14)),
            Expanded(
              child: Text('Notifiche',
                  style: OnlistTextStyles.hn(
                      fontSize: R.sp(16),
                      fontWeight: FontWeight.w400,
                      color: OnlistColors.white)),
            ),
            ValueListenableBuilder<int>(
              valueListenable: BadgeService().notificationBadgeCount,
              builder: (context, count, child) {
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  margin: EdgeInsets.only(right: R.sp(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                );
              },
            ),
            Icon(Icons.chevron_right,
                color: OnlistColors.white.withValues(alpha: 0.4), size: R.sp(20)),
          ],
        ),
      ),
    );
  }
  */

  /// Riga del blocco azioni. Altezza FISSA per tutte (con o senza sottotitolo)
  /// così la spaziatura resta uniforme; `color` tinge icona+label+chevron ed è
  /// l'unica differenza tra riga normale e distruttiva.
  Widget _buildActionTile({
    required IconData icon,
    required String label,
    String? subtitle,
    Color color = OnlistColors.white,
    required VoidCallback onTap,
  }) {
    final bool isDestructive = color != OnlistColors.white;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: R.sp(_actionRowHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: R.sp(16)),
          child: Row(
            children: [
              Icon(
                icon,
                // Il blu brand #1E00FF su fondo nero è illeggibile: righe
                // normali con icona bianca, come la label (scelta di Luca).
                color: isDestructive ? color : OnlistColors.white.withValues(alpha: 0.85),
                size: R.sp(22),
              ),
              SizedBox(width: R.sp(14)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OnlistTextStyles.hn(
                        fontSize: R.sp(16),
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OnlistTextStyles.hn(
                          fontSize: R.sp(12),
                          fontWeight: FontWeight.w400,
                          color: OnlistColors.white.withValues(alpha: 0.45),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDestructive
                    ? color.withValues(alpha: 0.6)
                    : OnlistColors.white.withValues(alpha: 0.35),
                size: R.sp(20),
              ),
            ],
          ),
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
      // CSS NUOVO: card 357×108 r10 con foto a tutta card e nome 32/700
      // CENTRATO sopra (prima: 120px, nome in basso a sinistra).
      child: Container(
        margin: EdgeInsets.fromLTRB(R.sp(18), 0, R.sp(18), R.sp(10)),
        height: R.sp(108),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.sp(10)),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF0009FF), Color(0xFF000599)],
            stops: [0.0, 0.8173],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(R.sp(10)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (fotoUrl != null)
                CachedNetworkImage(
                  imageUrl: fotoUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              // Velo scuro per la leggibilità del nome sopra la foto.
              ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: R.sp(16)),
                  child: Text(
                    nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OnlistTextStyles.hn(
                      fontSize: R.sp(32),
                      fontWeight: FontWeight.w700,
                      color: OnlistColors.white,
                      height: 37 / 32,
                      letterSpacing: -0.08 * 32,
                    ),
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

