/// A small, intentional well-being activity the user can complete once a day.
///
/// Completing the day's task earns the **mindful streak** (see
/// [MindfulStreakService]): unlike the usage streak, it is only fed by doing
/// something genuinely good for you — ideally something that pulls you away
/// from the screen for a few minutes.
class MindfulTask {
  const MindfulTask({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
  });

  /// Stable identifier persisted in preferences (e.g. `mindful.meditate`).
  final String id;

  /// Emoji used as the task's visual identity across the UI.
  final String emoji;

  /// Short imperative label, e.g. "Meditate for 5 minutes".
  final String title;

  /// One or two sentences of encouragement / how-to.
  final String description;

  /// The full catalog of daily tasks, shown in a stable one-per-day rotation.
  static const List<MindfulTask> catalog = [
    MindfulTask(
      id: 'mindful.meditate',
      emoji: '🧘',
      title: 'Meditate for 5 minutes',
      description: 'Sit comfortably, close your eyes and follow your breath. '
          'Five quiet minutes reset an overstimulated mind.',
    ),
    MindfulTask(
      id: 'mindful.profound-talk',
      emoji: '💬',
      title: 'Share a profound thought',
      description: 'Have a conversation where you share an idea that truly '
          'matters to you — no phones on the table.',
    ),
    MindfulTask(
      id: 'mindful.walk',
      emoji: '🚶',
      title: 'Take a 15-minute phone-free walk',
      description: 'Leave the phone in your pocket and just notice the world: '
          'sounds, light, people, air.',
    ),
    MindfulTask(
      id: 'mindful.gratitude',
      emoji: '🙏',
      title: 'Write down 3 things you are grateful for',
      description: 'Small is fine — good coffee, a friend, a sunny morning. '
          'Gratitude trains your attention away from the feed.',
    ),
    MindfulTask(
      id: 'mindful.read',
      emoji: '📖',
      title: 'Read 10 pages of a book',
      description: 'Paper beats the endless scroll. Ten pages a day is '
          'roughly 15 books a year.',
    ),
    MindfulTask(
      id: 'mindful.move',
      emoji: '💪',
      title: 'Move your body for 10 minutes',
      description: 'Stretch, do push-ups, dance in your room — anything that '
          'reminds you that you have a body, not just a thumb.',
    ),
    MindfulTask(
      id: 'mindful.call',
      emoji: '📞',
      title: 'Call someone you love',
      description: 'A real voice-to-voice conversation beats a hundred likes. '
          'Ask how they really are.',
    ),
    MindfulTask(
      id: 'mindful.breathe',
      emoji: '🌬️',
      title: 'Do 2 minutes of slow breathing',
      description: 'Inhale 4 seconds, exhale 8. Ten slow breaths tell your '
          'nervous system that everything is okay.',
    ),
    MindfulTask(
      id: 'mindful.screenless-meal',
      emoji: '🍽️',
      title: 'Eat one meal without any screen',
      description: 'No phone, no TV, no laptop. Notice how different a meal '
          'feels when it is the only thing happening.',
    ),
    MindfulTask(
      id: 'mindful.journal',
      emoji: '✍️',
      title: 'Journal for 10 minutes',
      description: 'Dump whatever is on your mind onto paper. Thoughts look '
          'smaller written down than swirling in your head.',
    ),
    MindfulTask(
      id: 'mindful.sky',
      emoji: '🌅',
      title: 'Watch the sky for 5 minutes',
      description: 'Sunrise, sunset, clouds or stars — look up and out. '
          'Perspective is the antidote to the feed.',
    ),
    MindfulTask(
      id: 'mindful.tidy',
      emoji: '🧹',
      title: 'Tidy one small space',
      description: 'A desk, a drawer, your bed. An ordered corner of the '
          'world quietly orders the mind too.',
    ),
    MindfulTask(
      id: 'mindful.water',
      emoji: '💧',
      title: 'Drink a big glass of water and stretch',
      description: 'The two most forgotten basics. Your future self says '
          'thanks.',
    ),
    MindfulTask(
      id: 'mindful.silence',
      emoji: '☕',
      title: 'Sit in silence with a drink',
      description: 'Tea, coffee, water — drink it slowly with no podcast, no '
          'music, no scrolling. Just you and the cup.',
    ),
    MindfulTask(
      id: 'mindful.compliment',
      emoji: '🌟',
      title: 'Give someone a sincere compliment',
      description: 'Make it specific and true. Brightening someone else\'s '
          'day is the fastest way to brighten your own.',
    ),
  ];

  /// Finds a task by [id], or null when no task matches.
  static MindfulTask? byId(String id) {
    for (final task in catalog) {
      if (task.id == id) return task;
    }
    return null;
  }
}
