import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class _Question {
  final String text;
  final List<String> options;
  final int correctIndex;
  const _Question(this.text, this.options, this.correctIndex);
}

// Deliberately kept to widely-known, non-controversial basics (pillars of
// Islam, well-known Quran/Seerah facts) - a light time-killer for idle
// waits between requests, not a fiqh reference, so nothing here touches
// disputed or sectarian points.
const List<_Question> _questions = [
  _Question('كم عدد أركان الإسلام؟', ['3', '4', '5', '6'], 2),
  _Question(
    'ما هو الركن الأول من أركان الإسلام؟',
    ['الصلاة', 'الشهادتان', 'الصيام', 'الزكاة'],
    1,
  ),
  _Question('كم عدد الصلوات المفروضة في اليوم والليلة؟', ['3', '4', '5', '6'], 2),
  _Question(
    'في أي شهر هجري يجب صيام رمضان؟',
    ['شعبان', 'رمضان', 'شوال', 'ذو الحجة'],
    1,
  ),
  _Question('كم عدد سور القرآن الكريم؟', ['100', '110', '114', '120'], 2),
  _Question(
    'ما هي أول سورة في ترتيب المصحف؟',
    ['البقرة', 'الفاتحة', 'الناس', 'الإخلاص'],
    1,
  ),
  _Question(
    'ما هي أطول سورة في القرآن الكريم؟',
    ['البقرة', 'آل عمران', 'يوسف', 'الكهف'],
    0,
  ),
  _Question(
    'ما اسم النبي الذي ابتلعه الحوت؟',
    ['نوح عليه السلام', 'يونس عليه السلام', 'موسى عليه السلام', 'يوسف عليه السلام'],
    1,
  ),
  _Question('كم عدد الأنبياء المذكورين بالاسم في القرآن الكريم؟', ['20', '25', '30', '35'], 1),
  _Question(
    'ما هي القبلة التي يتجه إليها المسلمون في الصلاة؟',
    ['المسجد الأقصى', 'الكعبة المشرفة', 'المدينة المنورة', 'جبل الطور'],
    1,
  ),
  _Question(
    'في أي مدينة وُلد النبي محمد ﷺ؟',
    ['المدينة المنورة', 'مكة المكرمة', 'الطائف', 'القدس'],
    1,
  ),
  _Question(
    'من هو أول الخلفاء الراشدين؟',
    ['عمر بن الخطاب', 'أبو بكر الصديق', 'عثمان بن عفان', 'علي بن أبي طالب'],
    1,
  ),
  _Question(
    'ما هو الركن الخامس من أركان الإسلام؟',
    ['الزكاة', 'الصيام', 'الحج', 'الشهادتان'],
    2,
  ),
  _Question(
    'في أي شهر هجري تؤدى فريضة الحج؟',
    ['ذو القعدة', 'ذو الحجة', 'محرم', 'رجب'],
    1,
  ),
  _Question('كم عدد ركعات صلاة الفجر (الفرض)؟', ['2', '3', '4', '5'], 0),
  _Question(
    'ما اسم الكتاب المقدس عند المسلمين؟',
    ['التوراة', 'الإنجيل', 'القرآن الكريم', 'الزبور'],
    2,
  ),
  _Question(
    'من الذي رفع قواعد الكعبة المشرفة بأمر الله؟',
    ['إبراهيم وإسماعيل عليهما السلام', 'نوح عليه السلام', 'آدم عليه السلام', 'موسى عليه السلام'],
    0,
  ),
  _Question(
    'ما اسم الليلة التي نزل فيها القرآن الكريم؟',
    ['ليلة القدر', 'ليلة الإسراء والمعراج', 'ليلة النصف من شعبان', 'ليلة عاشوراء'],
    0,
  ),
  _Question(
    'ما هي زوجة النبي ﷺ الأولى؟',
    ['عائشة رضي الله عنها', 'خديجة رضي الله عنها', 'حفصة رضي الله عنها', 'زينب رضي الله عنها'],
    1,
  ),
  _Question(
    'ما اسم المسجد الذي بُني في المدينة المنورة أول الهجرة؟',
    ['المسجد الأقصى', 'مسجد قباء', 'المسجد الحرام', 'مسجد الخيف'],
    1,
  ),
];

/// A light general-Islamic-knowledge quiz - something for a captain to
/// spend a few minutes with while idle between requests, entirely
/// offline/self-contained (no network, no new backend).
class IslamicQuizScreen extends StatefulWidget {
  const IslamicQuizScreen({super.key});

  @override
  State<IslamicQuizScreen> createState() => _IslamicQuizScreenState();
}

class _IslamicQuizScreenState extends State<IslamicQuizScreen> {
  late List<_Question> _round;
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startNewRound();
  }

  void _startNewRound() {
    _round = [..._questions]..shuffle();
    _index = 0;
    _score = 0;
    _selected = null;
    _finished = false;
    setState(() {});
  }

  void _select(int optionIndex) {
    if (_selected != null) return; // Already answered this question.
    setState(() {
      _selected = optionIndex;
      if (optionIndex == _round[_index].correctIndex) _score++;
    });
  }

  void _next() {
    if (_index + 1 >= _round.length) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('أسئلة دينية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'جولة جديدة',
            onPressed: _startNewRound,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _finished ? _buildResult() : _buildQuestion(),
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final question = _round[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'سؤال ${_index + 1} من ${_round.length}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
                fontFamily: 'Cairo',
              ),
            ),
            Text(
              'النتيجة: $_score',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_index) / _round.length,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Text(
            question.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            itemCount: question.options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final isCorrect = i == question.correctIndex;
              final isSelected = i == _selected;
              Color background = Colors.white;
              Color border = AppColors.border;
              Color text = AppColors.darkText;
              if (_selected != null) {
                if (isCorrect) {
                  background = AppColors.success.withOpacity(0.12);
                  border = AppColors.success;
                  text = AppColors.success;
                } else if (isSelected) {
                  background = AppColors.error.withOpacity(0.12);
                  border = AppColors.error;
                  text = AppColors.error;
                }
              }
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _select(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          question.options[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: text,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      if (_selected != null && isCorrect)
                        const Icon(Icons.check_circle_rounded, color: AppColors.success)
                      else if (_selected != null && isSelected)
                        const Icon(Icons.cancel_rounded, color: AppColors.error),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _selected == null ? null : _next,
          child: Text(
            _index + 1 >= _round.length ? 'عرض النتيجة' : 'السؤال التالي',
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final total = _round.length;
    final ratio = total == 0 ? 0.0 : _score / total;
    final String message;
    if (ratio >= 0.8) {
      message = 'ممتاز! معلوماتك الدينية رائعة 🌟';
    } else if (ratio >= 0.5) {
      message = 'جيد جدًا، واصل التعلم 👍';
    } else {
      message = 'حاول مرة أخرى، كل جولة فرصة جديدة';
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            '$_score من $total',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _startNewRound,
            child: const Text('جولة جديدة'),
          ),
        ],
      ),
    );
  }
}
