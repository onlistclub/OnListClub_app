// ignore_for_file: prefer_const_constructors
/// Dati seed locali per sviluppo e test UI senza rete.
/// Utilizzabili in widget test, golden test, o come fallback in debug mode.
///
/// Utilizzo:
///   import 'package:onlistclub/core/utils/seed_data.dart';
///   final clubs = SeedData.locali;
///   final events = SeedData.eventi;

import '../models/locale_model.dart';
import '../models/serata_model.dart';

abstract class SeedData {
  // ── Locali fittizi ─────────────────────────────────────────────────────────

  static final List<LocaleModel> locali = [
    LocaleModel(
      id: 'seed-locale-001',
      nome: 'Amnesia Club',
      indirizzo: 'Via Alfonso Gatto 4',
      nomeCitta: 'Milano',
      idCitta: 'seed-citta-mi',
      famosita: 950,
      generiMusicali: ['Trap', 'Techno House'],
      fotoUrl:
          'https://images.unsplash.com/photo-1545128485-c400e7702796?w=800&q=80',
      prezzoIndicativo: 4,
      descrizione: 'Uno dei club più iconici di Milano, famoso per le notti techno e trap.',
      lat: 45.4654,
      lng: 9.1866,
    ),
    LocaleModel(
      id: 'seed-locale-002',
      nome: 'Volt Club',
      indirizzo: 'Via Lavoratori Autobianchi 1',
      nomeCitta: 'Sesto San Giovanni',
      idCitta: 'seed-citta-ssg',
      famosita: 820,
      generiMusicali: ['Techno', 'Industrial'],
      fotoUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=80',
      prezzoIndicativo: 3,
      descrizione: 'Club underground dedicato alla musica techno industriale.',
      lat: 45.5358,
      lng: 9.2364,
    ),
    LocaleModel(
      id: 'seed-locale-003',
      nome: 'Fabrique',
      indirizzo: 'Via Fantoli 9',
      nomeCitta: 'Milano',
      idCitta: 'seed-citta-mi',
      famosita: 780,
      generiMusicali: ['House', 'Commercial'],
      fotoUrl:
          'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&q=80',
      prezzoIndicativo: 3,
      descrizione: 'Grande venue per concerti e serate clubbing a Milano Est.',
      lat: 45.4512,
      lng: 9.2301,
    ),
    LocaleModel(
      id: 'seed-locale-004',
      nome: 'Cocoricò',
      indirizzo: 'Via Chieti 44',
      nomeCitta: 'Riccione',
      idCitta: 'seed-citta-rc',
      famosita: 1000,
      generiMusicali: ['Techno', 'Trance', 'House'],
      fotoUrl:
          'https://images.unsplash.com/photo-1571266028243-e4733b0f0bb0?w=800&q=80',
      prezzoIndicativo: 3,
      descrizione: 'La piramide della notte italiana — club leggendario sulla Riviera romagnola.',
      lat: 43.9967,
      lng: 12.6664,
    ),
    LocaleModel(
      id: 'seed-locale-005',
      nome: 'Praja',
      indirizzo: 'Via Galileo Galilei',
      nomeCitta: 'Gallipoli',
      idCitta: 'seed-citta-le',
      famosita: 870,
      generiMusicali: ['House', 'Afro', 'Commercial'],
      fotoUrl:
          'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&q=80',
      prezzoIndicativo: 2,
      descrizione: 'La discoteca estiva più famosa del Sud Italia, sulla spiaggia di Gallipoli.',
      lat: 40.0566,
      lng: 17.9929,
    ),
  ];

  // ── Serate fittizie con date future ────────────────────────────────────────

  static List<SerataModel> get eventi {
    final oggi = DateTime.now();
    final domani = oggi.add(const Duration(days: 1));
    final tra3 = oggi.add(const Duration(days: 3));
    final tra7 = oggi.add(const Duration(days: 7));
    final tra14 = oggi.add(const Duration(days: 14));
    final tra21 = oggi.add(const Duration(days: 21));

    return [
      // Amnesia — quasi sold out (ultimi posti)
      SerataModel(
        id: 'seed-evento-001',
        clubId: 'seed-locale-001',
        nome: 'The Club',
        data: domani,
        oraApertura: '23:00',
        oraChiusura: '04:00',
        ingressiPrevisti: 500,
        postiPrenotati: 420,
        locandinaUrl:
            'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&q=80',
        generiMusicali: ['Trap', 'Techno House'],
        stato: 'attivo',
        prezzoIngresso: 15.0,
      ),
      // Volt — sold out
      SerataModel(
        id: 'seed-evento-002',
        clubId: 'seed-locale-002',
        nome: 'Nocturnal',
        data: domani,
        oraApertura: '23:30',
        oraChiusura: '05:00',
        ingressiPrevisti: 300,
        postiPrenotati: 300,
        generiMusicali: ['Techno'],
        stato: 'attivo',
        prezzoIngresso: 12.0,
      ),
      // Fabrique — illimitato
      SerataModel(
        id: 'seed-evento-003',
        clubId: 'seed-locale-003',
        nome: 'Friday Fever',
        data: tra3,
        oraApertura: '23:00',
        oraChiusura: '05:00',
        ingressiPrevisti: 0,
        postiPrenotati: 0,
        generiMusicali: ['House', 'Commercial'],
        stato: 'attivo',
        prezzoIngresso: 18.0,
      ),
      // Amnesia — weekend successivo
      SerataModel(
        id: 'seed-evento-004',
        clubId: 'seed-locale-001',
        nome: 'Techno Marathon',
        data: tra7,
        oraApertura: '22:00',
        oraChiusura: '06:00',
        ingressiPrevisti: 500,
        postiPrenotati: 120,
        generiMusicali: ['Techno House'],
        stato: 'attivo',
        prezzoIngresso: 20.0,
      ),
      // Cocoricò — tra 2 settimane
      SerataModel(
        id: 'seed-evento-005',
        clubId: 'seed-locale-004',
        nome: 'Estate Forever',
        data: tra14,
        oraApertura: '22:30',
        oraChiusura: '06:00',
        ingressiPrevisti: 2000,
        postiPrenotati: 850,
        generiMusicali: ['Trance', 'Techno'],
        stato: 'attivo',
        prezzoIngresso: 25.0,
      ),
      // Praja — tra 3 settimane
      SerataModel(
        id: 'seed-evento-006',
        clubId: 'seed-locale-005',
        nome: 'Afro Night',
        data: tra21,
        oraApertura: '23:00',
        oraChiusura: '05:00',
        ingressiPrevisti: 1500,
        postiPrenotati: 200,
        generiMusicali: ['Afro', 'House'],
        stato: 'attivo',
        prezzoIngresso: 15.0,
      ),
    ];
  }

  // ── Utenti di test ─────────────────────────────────────────────────────────
  // Nota: gli utenti reali sono gestiti da Supabase Auth.
  // Questi sono semplici mappe dati per test UI (es. profilo visualizzato).

  static final List<Map<String, dynamic>> utenti = [
    {
      'id': 'seed-user-001',
      'email': 'mario.rossi@test.onlist.app',
      'nome': 'Mario',
      'cognome': 'Rossi',
      'data_nascita': '1998-05-15',
      'maggiorenne': true,
    },
    {
      'id': 'seed-user-002',
      'email': 'giulia.bianchi@test.onlist.app',
      'nome': 'Giulia',
      'cognome': 'Bianchi',
      'data_nascita': '2000-11-03',
      'maggiorenne': true,
    },
    {
      'id': 'seed-user-003',
      'email': 'luca.verdi@test.onlist.app',
      'nome': 'Luca',
      'cognome': 'Verdi',
      'data_nascita': '2005-07-20',
      'maggiorenne': false,
    },
  ];
}
