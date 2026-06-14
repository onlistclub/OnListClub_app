import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../core/utils/analytics_mixin.dart';
import '../../theme/onlist_colors.dart';
import '../../theme/onlist_text_styles.dart';
import 'bloc/location_manual_bloc.dart';

class LocationManualScreen extends StatefulWidget {
  const LocationManualScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    return BlocProvider<LocationManualBloc>(
      create: (_) => LocationManualBloc(),
      child: const LocationManualScreen(),
    );
  }

  @override
  State<LocationManualScreen> createState() => _LocationManualScreenState();
}

class _LocationManualScreenState extends State<LocationManualScreen> with ScreenAnalytics {
  @override
  String get screenName => 'location_manual';

  final TextEditingController _cittaCtrl = TextEditingController();
  final TextEditingController _capCtrl = TextEditingController();

  @override
  void dispose() {
    _cittaCtrl.dispose();
    _capCtrl.dispose();
    super.dispose();
  }

  static const TextStyle _fieldInput = TextStyle(
    fontFamily: 'HelveticaNeue',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: OnlistColors.white,
  );

  static const TextStyle _fieldLabel = TextStyle(
    fontFamily: 'HelveticaNeue',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: OnlistColors.white,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: OnlistColors.onboardingBackground),
        child: BlocConsumer<LocationManualBloc, LocationManualState>(
          listener: (context, state) {
            if (state.isSuccess) {
              NavigatorService.pushNamedAndRemoveUntil(
                  AppRoutes.eventDetailScreen);
            }
            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
              showAppErrorDialog(context, state.errorMessage!);
            }
            if (state.selectedCitta != null &&
                _cittaCtrl.text != state.selectedCitta!.nomeCitta) {
              _cittaCtrl.text = state.selectedCitta!.nomeCitta;
              _cittaCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _cittaCtrl.text.length),
              );
              // Auto-compilo il CAP SOLO quando cambia la città (qui), così
              // un'eventuale modifica manuale del CAP non viene sovrascritta
              // ai rebuild successivi (es. cambio raggio).
              _capCtrl.text = state.selectedCitta!.cap ?? '';
            }
          },
          builder: (context, state) {
            final bloc = context.read<LocationManualBloc>();
            final hasSuggestions = state.cities.isNotEmpty;

            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),

                  // Titolo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Inserisci la tua posizione',
                      style: OnlistTextStyles.title20Medium,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card con campi Città e Cap
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [OnlistColors.black, Color(0xFF0006CA)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft:
                              Radius.circular(hasSuggestions ? 0 : 16),
                          bottomRight:
                              Radius.circular(hasSuggestions ? 0 : 16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Campo Città
                          const Text('Città', style: _fieldLabel),
                          TextField(
                            controller: _cittaCtrl,
                            style: _fieldInput,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              contentPadding: const EdgeInsets.only(top: 4, bottom: 6),
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white, width: 2),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white, width: 2),
                              ),
                              suffixIcon: state.isLoadingCities
                                  ? const Padding(
                                      padding: EdgeInsets.only(bottom: 4),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          color: Colors.white54,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : (state.selectedCitta != null
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.greenAccent, size: 20)
                                      : null),
                            ),
                            onChanged: (v) => bloc.add(SearchCittaEvent(v)),
                          ),
                          const SizedBox(height: 16),
                          // Campo Cap
                          const Text('Cap', style: _fieldLabel),
                          TextField(
                            controller: _capCtrl,
                            keyboardType: TextInputType.number,
                            style: _fieldInput,
                            decoration: const InputDecoration(
                              isDense: true,
                              filled: false,
                              contentPadding: EdgeInsets.only(top: 4, bottom: 6),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white, width: 2),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Lista suggerimenti città
                  if (hasSuggestions)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D0080),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.cities.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          itemBuilder: (context, i) {
                            final c = state.cities[i];
                            final label = (c.cap != null && c.cap!.isNotEmpty)
                                ? '${c.cap} - ${c.nomeCitta}'
                                : c.nomeCitta;
                            return InkWell(
                              onTap: () => bloc.add(SelectCittaEvent(c)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontFamily: 'HelveticaNeue',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: OnlistColors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  const Spacer(flex: 3),

                  // Bottone Entra
                  Center(
                    child: SizedBox(
                      width: 150,
                      height: 40,
                      child: ElevatedButton(
                        onPressed:
                            (state.isLoading || state.selectedCitta == null)
                                ? null
                                : () => bloc.add(const SubmitLocationEvent()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OnlistColors.white,
                          foregroundColor: OnlistColors.black,
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.35),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: state.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text('Entra', style: OnlistTextStyles.button16Bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
