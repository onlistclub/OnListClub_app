import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_export.dart';
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

class _LocationManualScreenState extends State<LocationManualScreen> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0000FF),
      body: BlocConsumer<LocationManualBloc, LocationManualState>(
        listener: (context, state) {
          if (state.isSuccess) {
            NavigatorService.pushNamedAndRemoveUntil(
                AppRoutes.eventDetailScreen);
          }
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
          // Sincronizza il controller quando l'utente seleziona una città
          if (state.selectedCitta != null &&
              _ctrl.text != state.selectedCitta!.nomeCitta) {
            _ctrl.text = state.selectedCitta!.nomeCitta;
            _ctrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _ctrl.text.length),
            );
          }
        },
        builder: (context, state) {
          final bloc = context.read<LocationManualBloc>();
          final hasSuggestions = state.cities.isNotEmpty;

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                // Titolo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Inserisci la tua posizione',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Card con campo città
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0066),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft:
                            Radius.circular(hasSuggestions ? 0 : 16),
                        bottomRight:
                            Radius.circular(hasSuggestions ? 0 : 16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Città',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              enabledBorder: const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.white54),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.white, width: 1.5),
                              ),
                              contentPadding:
                                  const EdgeInsets.only(bottom: 8),
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
                                          color: Colors.greenAccent,
                                          size: 20)
                                      : null),
                            ),
                            onChanged: (v) =>
                                bloc.add(SearchCittaEvent(v)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Lista suggerimenti
                if (hasSuggestions)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
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
                          return InkWell(
                            onTap: () =>
                                bloc.add(SelectCittaEvent(c)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              child: Text(
                                c.nomeCitta,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                // Bottone Entra
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (state.isLoading ||
                              state.selectedCitta == null)
                          ? null
                          : () => bloc.add(const SubmitLocationEvent()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.black.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
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
                          : Text(
                              'Entra',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
