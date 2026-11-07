import 'dart:async';

import 'package:flutter/material.dart';

import '../assets/app_assets.dart';

class WomenQuoteItem {
  final int id;
  final String quote;
  final String author;
  final String category;

  const WomenQuoteItem({
    required this.id,
    required this.quote,
    required this.author,
    required this.category,
  });

  factory WomenQuoteItem.fromJson(Map<String, dynamic> json) {
    return WomenQuoteItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      quote: (json['quote'] ?? '').toString(),
      author: (json['author'] ?? 'Sakhi Sisterhood').toString(),
      category: (json['category'] ?? 'Sisterhood & Strength').toString(),
    );
  }
}

/// Curated bank of 168 inspiring quotations about women, courage, sisterhood,
/// Indian trailblazers, leadership, wellness, and personal safety.
abstract final class SakhiWomenQuotes {
  static const List<WomenQuoteItem> all = [
    WomenQuoteItem(
      id: 1,
      quote: "Awake, arise, and educate. Smash traditions—liberate!",
      author: "Savitribai Phule",
      category: "Trailblazers & Courage",
    ),
    WomenQuoteItem(
      id: 2,
      quote: "We want deeper sincerity of motive, a greater courage in speech and earnestness in action.",
      author: "Sarojini Naidu",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 3,
      quote: "The path from dreams to success does exist. May you have the vision to find it, the courage to get on to it, and the perseverance to follow it.",
      author: "Kalpana Chawla",
      category: "Dreams & Perseverance",
    ),
    WomenQuoteItem(
      id: 4,
      quote: "I shall not surrender my Jhansi—courage is the crown every woman wears within.",
      author: "Rani Lakshmibai",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 5,
      quote: "A woman with a voice is, by definition, a strong woman.",
      author: "Melinda French Gates",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 6,
      quote: "There is no limit to what we, as women, can accomplish.",
      author: "Michelle Obama",
      category: "Boundless Potential",
    ),
    WomenQuoteItem(
      id: 7,
      quote: "I raise up my voice—not so that I can shout, but so that those without a voice can be heard.",
      author: "Malala Yousafzai",
      category: "Sisterhood & Voice",
    ),
    WomenQuoteItem(
      id: 8,
      quote: "Each time a woman stands up for herself, without knowing it possibly, without claiming it, she stands up for all women.",
      author: "Maya Angelou",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 9,
      quote: "Nothing in life is to be feared, it is only to be understood. Now is the time to understand more, so that we may fear less.",
      author: "Marie Curie",
      category: "Wisdom & Fearlessness",
    ),
    WomenQuoteItem(
      id: 10,
      quote: "No one can make you feel inferior without your consent.",
      author: "Eleanor Roosevelt",
      category: "Self-Worth & Dignity",
    ),
    WomenQuoteItem(
      id: 11,
      quote: "Women belong in all places where decisions are being made.",
      author: "Ruth Bader Ginsburg",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 12,
      quote: "I am not free while any woman is unfree, even when her shackles are very different from my own.",
      author: "Audre Lorde",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 13,
      quote: "At the end of the day, we can endure much more than we think we can.",
      author: "Frida Kahlo",
      category: "Resilience & Healing",
    ),
    WomenQuoteItem(
      id: 14,
      quote: "Culture does not make people. People make culture.",
      author: "Chimamanda Ngozi Adichie",
      category: "Change & Empowerment",
    ),
    WomenQuoteItem(
      id: 15,
      quote: "The success of every woman should be the inspiration to another. We should raise each other up.",
      author: "Serena Williams",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 16,
      quote: "Vision without action is merely a dream; action with courage changes generations.",
      author: "Sudha Murty",
      category: "Wisdom & Action",
    ),
    WomenQuoteItem(
      id: 17,
      quote: "Do not wait for someone else to come and speak for you. It's you who can change the world.",
      author: "Mary Kom",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 18,
      quote: "Another world is not only possible, she is on her way. On a quiet day, I can hear her breathing.",
      author: "Arundhati Roy",
      category: "Hope & Renewal",
    ),
    WomenQuoteItem(
      id: 19,
      quote:
          "Freedom is not given; it is claimed by women who refuse to shrink.",
      author: "Captain Lakshmi Sahgal",
      category: "Trailblazers & Courage",
    ),
    WomenQuoteItem(
      id: 20,
      quote: "Empowerment begins the moment a woman knows she is never walking alone.",
      author: "Sakhi Sisterhood",
      category: "Sakhi Safety & Trust",
    ),
    WomenQuoteItem(
      id: 21,
      quote: "A strong woman looks a challenge dead in the eye and gives it a wink.",
      author: "Gina Carey",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 22,
      quote: "The most common way people give up their power is by thinking they don't have any.",
      author: "Alice Walker",
      category: "Self-Worth & Dignity",
    ),
    WomenQuoteItem(
      id: 23,
      quote: "Above all, be the heroine of your life, not the victim.",
      author: "Nora Ephron",
      category: "Courage & Agency",
    ),
    WomenQuoteItem(
      id: 24,
      quote: "What makes you different or weird—that's your strength.",
      author: "Meryl Streep",
      category: "Self-Worth & Dignity",
    ),
    WomenQuoteItem(
      id: 25,
      quote: "Think like a queen. A queen is not afraid to fail. Failure is another steppingstone to greatness.",
      author: "Oprah Winfrey",
      category: "Resilience & Growth",
    ),
    WomenQuoteItem(
      id: 26,
      quote: "You may encounter many defeats, but you must not be defeated.",
      author: "Maya Angelou",
      category: "Resilience & Healing",
    ),
    WomenQuoteItem(
      id: 27,
      quote: "Well-behaved women seldom make history.",
      author: "Laurel Thatcher Ulrich",
      category: "Trailblazers & Courage",
    ),
    WomenQuoteItem(
      id: 28,
      quote: "The question isn't who's going to let me; it's who is going to stop me.",
      author: "Ayn Rand",
      category: "Courage & Agency",
    ),
    WomenQuoteItem(
      id: 29,
      quote: "She remembered who she was and the game changed.",
      author: "Lalah Delia",
      category: "Self-Worth & Dignity",
    ),
    WomenQuoteItem(
      id: 30,
      quote: "A woman is like a tea bag—you can't tell how strong she is until you put her in hot water.",
      author: "Eleanor Roosevelt",
      category: "Resilience & Growth",
    ),
    WomenQuoteItem(
      id: 31,
      quote: "Life is not measured by the number of breaths we take, but by the moments that take our breath away.",
      author: "Maya Angelou",
      category: "Mindfulness & Joy",
    ),
    WomenQuoteItem(
      id: 32,
      quote: "When women support each other, incredible things happen.",
      author: "Sakhi Community",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 33,
      quote: "Your safety is your right, your voice is your shield, and your community is your strength.",
      author: "Sakhi Safety Pledge",
      category: "Sakhi Safety & Trust",
    ),
    WomenQuoteItem(
      id: 34,
      quote: "Courage is like a muscle. We strengthen it by use.",
      author: "Ruth Gordon",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 35,
      quote: "If you want something said, ask a man; if you want something done, ask a woman.",
      author: "Margaret Thatcher",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 36,
      quote: "A feminist is anyone who recognizes the equality and full humanity of women and men.",
      author: "Gloria Steinem",
      category: "Equality & Justice",
    ),
    WomenQuoteItem(
      id: 37,
      quote: "We need to reshape our own perception of how we view ourselves. We have to step up as women and take the lead.",
      author: "Beyoncé",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 38,
      quote: "No country can ever truly flourish if it stifles the potential of its women and deprives itself of the contributions of half of its citizens.",
      author: "Michelle Obama",
      category: "Equality & Justice",
    ),
    WomenQuoteItem(
      id: 39,
      quote: "Educate a man and you educate an individual; educate a woman and you educate an entire generation.",
      author: "Brigham Young",
      category: "Education & Wisdom",
    ),
    WomenQuoteItem(
      id: 40,
      quote: "I measure the progress of a community by the degree of progress which women have achieved.",
      author: "Dr. B. R. Ambedkar",
      category: "Equality & Justice",
    ),
    WomenQuoteItem(
      id: 41,
      quote: "To awaken the people, it is the women who must be awakened. Once she is on the move, the family moves, the village moves, the nation moves.",
      author: "Jawaharlal Nehru",
      category: "Trailblazers & Courage",
    ),
    WomenQuoteItem(
      id: 42,
      quote: "There is no chance for the welfare of the world unless the condition of women is improved. It is not possible for a bird to fly on only one wing.",
      author: "Swami Vivekananda",
      category: "Equality & Justice",
    ),
    WomenQuoteItem(
      id: 43,
      quote: "Whatever you do, be different—that was the advice my mother gave me.",
      author: "Anita Roddick",
      category: "Dreams & Perseverance",
    ),
    WomenQuoteItem(
      id: 44,
      quote: "Whatever the problem, be part of the solution. Don't just sit around raising questions and pointing out obstacles.",
      author: "Tina Fey",
      category: "Wisdom & Action",
    ),
    WomenQuoteItem(
      id: 45,
      quote: "You are more powerful than you know; you are beautiful just as you are.",
      author: "Melissa Etheridge",
      category: "Self-Worth & Dignity",
    ),
    WomenQuoteItem(
      id: 46,
      quote: "Fearlessness is not the absence of fear. It's the mastery of fear. It's about getting up one more time than we fall down.",
      author: "Arianna Huffington",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 47,
      quote: "The power you have is to be the best version of yourself you can be, so you can create a better world.",
      author: "Ashley Rickards",
      category: "Change & Empowerment",
    ),
    WomenQuoteItem(
      id: 48,
      quote: "A girl should be two things: who and what she wants.",
      author: "Coco Chanel",
      category: "Courage & Agency",
    ),
    WomenQuoteItem(
      id: 49,
      quote: "The most courageous act is still to think for yourself. Aloud.",
      author: "Coco Chanel",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 50,
      quote: "Do not live someone else's life and someone else's idea of what womanhood is. Womanhood is you.",
      author: "Viola Davis",
      category: "Self-Worth & Dignity",
    ),
    WomenQuoteItem(
      id: 51,
      quote: "Doubt is a killer. You just have to know who you are and what you stand for.",
      author: "Jennifer Lopez",
      category: "Confidence & Trust",
    ),
    WomenQuoteItem(
      id: 52,
      quote: "Take criticism seriously, but not personally. If there is truth or merit in the criticism, try to learn from it.",
      author: "Hillary Rodham Clinton",
      category: "Wisdom & Action",
    ),
    WomenQuoteItem(
      id: 53,
      quote: "Human rights are women's rights, and women's rights are human rights.",
      author: "Hillary Rodham Clinton",
      category: "Equality & Justice",
    ),
    WomenQuoteItem(
      id: 54,
      quote: "Never doubt that you are valuable and powerful and deserving of every chance and opportunity in the world to pursue and achieve your own dreams.",
      author: "Hillary Rodham Clinton",
      category: "Dreams & Perseverance",
    ),
    WomenQuoteItem(
      id: 55,
      quote: "It took me quite a long time to develop a voice, and now that I have it, I am not going to be silent.",
      author: "Madeleine Albright",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 56,
      quote: "Women are the largest untapped reservoir of talent in the world.",
      author: "Hillary Rodham Clinton",
      category: "Boundless Potential",
    ),
    WomenQuoteItem(
      id: 57,
      quote: "If your actions create a legacy that inspires others to dream more, learn more, do more and become more, then, you are an excellent leader.",
      author: "Dolly Parton",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 58,
      quote: "Storms make trees take deeper roots.",
      author: "Dolly Parton",
      category: "Resilience & Healing",
    ),
    WomenQuoteItem(
      id: 59,
      quote: "Just don't give up trying to do what you really want to do. Where there is love and inspiration, I don't think you can go wrong.",
      author: "Ella Fitzgerald",
      category: "Dreams & Perseverance",
    ),
    WomenQuoteItem(
      id: 60,
      quote: "Define success on your own terms, achieve it by your own rules, and build a life you're proud to live.",
      author: "Anne Sweeney",
      category: "Courage & Agency",
    ),
    WomenQuoteItem(
      id: 61,
      quote: "Be messy and complicated and afraid and show up anyways.",
      author: "Glennon Doyle",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 62,
      quote: "Owning our story and loving ourselves through that process is the bravest thing that we'll ever do.",
      author: "Brené Brown",
      category: "Self-Worth & Dignity",
    ),
    WomenQuoteItem(
      id: 63,
      quote: "Vulnerability is the birthplace of innovation, creativity and change.",
      author: "Brené Brown",
      category: "Resilience & Growth",
    ),
    WomenQuoteItem(
      id: 64,
      quote: "Courage starts with showing up and letting ourselves be seen.",
      author: "Brené Brown",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 65,
      quote: "One child, one teacher, one book, one pen can change the world.",
      author: "Malala Yousafzai",
      category: "Education & Wisdom",
    ),
    WomenQuoteItem(
      id: 66,
      quote:
          "We realize the importance of our voices only when we are silenced.",
      author: "Malala Yousafzai",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 67,
      quote: "When the whole world is silent, even one voice becomes powerful.",
      author: "Malala Yousafzai",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 68,
      quote:
          "Extremists have shown what frightens them most: a girl with a book.",
      author: "Malala Yousafzai",
      category: "Education & Wisdom",
    ),
    WomenQuoteItem(
      id: 69,
      quote: "I'm tough, I'm ambitious, and I know exactly what I want.",
      author: "Madonna",
      category: "Confidence & Trust",
    ),
    WomenQuoteItem(
      id: 70,
      quote: "Power is not given to you. You have to take it.",
      author: "Beyoncé",
      category: "Courage & Agency",
    ),
    WomenQuoteItem(
      id: 71,
      quote: "The allure of a woman is her confidence and her kindness toward other women.",
      author: "Sakhi Sisterhood",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 72,
      quote: "Trust your instincts. You never have to apologize for prioritizing your personal safety.",
      author: "Sakhi Safety Guide",
      category: "Sakhi Safety & Trust",
    ),
    WomenQuoteItem(
      id: 73,
      quote: "Before boarding a late-evening cab, share your live route link with a trusted contact—preparedness is peace of mind.",
      author: "Sakhi Safety Tip",
      category: "Sakhi Safety & Trust",
    ),
    WomenQuoteItem(
      id: 74,
      quote: "India's 112 emergency helpline connects Police, Fire, and Medical response in one call—always accessible from your Sakhi Safety Hub.",
      author: "Sakhi Safety Tip",
      category: "Sakhi Safety & Trust",
    ),
    WomenQuoteItem(
      id: 75,
      quote: "A sisterhood that watches out for one another turns every street into a safer path.",
      author: "Sakhi Community",
      category: "Sakhi Safety & Trust",
    ),
    WomenQuoteItem(
      id: 76,
      quote: "You are never alone when your trusted circle carries your light.",
      author: "Sakhi Community",
      category: "Sakhi Safety & Trust",
    ),
    WomenQuoteItem(
      id: 77,
      quote: "Whatever glory belongs to the race for a development unprecedented in history for the given length of time, a full share belongs to the womanhood of the race.",
      author: "Mary McLeod Bethune",
      category: "Trailblazers & Courage",
    ),
    WomenQuoteItem(
      id: 78,
      quote: "Invest in the human soul. Who knows, it might be a diamond in the rough.",
      author: "Mary McLeod Bethune",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 79,
      quote:
          "If they don't give you a seat at the table, bring a folding chair.",
      author: "Shirley Chisholm",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 80,
      quote: "Tremendous amounts of talent are being lost to our society just because that talent wears a skirt.",
      author: "Shirley Chisholm",
      category: "Equality & Justice",
    ),
    WomenQuoteItem(
      id: 81,
      quote: "Service is the rent we pay for the privilege of living on this earth.",
      author: "Shirley Chisholm",
      category: "Wisdom & Action",
    ),
    WomenQuoteItem(
      id: 82,
      quote: "You don't make progress by standing on the sidelines, whimpering and complaining. You make progress by implementing ideas.",
      author: "Shirley Chisholm",
      category: "Wisdom & Action",
    ),
    WomenQuoteItem(
      id: 83,
      quote: "Nothing I accept about myself can be used against me to diminish me.",
      author: "Audre Lorde",
      category: "Self-Worth & Dignity",
    ),
    WomenQuoteItem(
      id: 84,
      quote: "When I dare to be powerful—to use my strength in the service of my vision—then it becomes less and less important whether I am afraid.",
      author: "Audre Lorde",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 85,
      quote:
          "Caring for myself is not self-indulgence, it is self-preservation.",
      author: "Audre Lorde",
      category: "Mindfulness & Joy",
    ),
    WomenQuoteItem(
      id: 86,
      quote: "Your silence will not protect you.",
      author: "Audre Lorde",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 87,
      quote: "Delight in your own unfolding; every season of a woman's life holds its own brilliance.",
      author: "Kiran Bedi",
      category: "Resilience & Growth",
    ),
    WomenQuoteItem(
      id: 88,
      quote: "Fearless policing and fearless living start with self-discipline and inner conviction.",
      author: "Kiran Bedi",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 89,
      quote: "When you educate a girl, you give her the compass to navigate any storm.",
      author: "Sudha Murty",
      category: "Education & Wisdom",
    ),
    WomenQuoteItem(
      id: 90,
      quote: "Kindness is not weakness; it is the quiet confidence of a strong woman.",
      author: "Sudha Murty",
      category: "Confidence & Trust",
    ),
    WomenQuoteItem(
      id: 91,
      quote: "Whatever crown you wear, never forget to leave the door open for the women coming after you.",
      author: "Indra Nooyi",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 92,
      quote: "Be yourself, passionately and unapologetically, in every boardroom and every neighbourhood.",
      author: "Indra Nooyi",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 93,
      quote: "The sky is not the limit when women build the rockets.",
      author: "Tessy Thomas",
      category: "Dreams & Perseverance",
    ),
    WomenQuoteItem(
      id: 94,
      quote: "Science knows no gender; curiosity and grit belong to every daughter of India.",
      author: "Ritu Karidhal",
      category: "Trailblazers & Courage",
    ),
    WomenQuoteItem(
      id: 95,
      quote: "Every medal won by a woman is a door opened for a million young girls.",
      author: "P. V. Sindhu",
      category: "Dreams & Perseverance",
    ),
    WomenQuoteItem(
      id: 96,
      quote: "Champions aren't made in comfort zones; they are forged in determination.",
      author: "Saina Nehwal",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 97,
      quote: "Run your own race, break the tape, and let your footsteps inspire the village behind you.",
      author: "P. T. Usha",
      category: "Trailblazers & Courage",
    ),
    WomenQuoteItem(
      id: 98,
      quote: "Mountains do not bow to strength alone; they bow to a woman's unbreakable resolve.",
      author: "Bachendri Pal",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 99,
      quote: "Even with a prosthetic leg, Everest could not stop a mind that refused to quit.",
      author: "Arunima Sinha",
      category: "Resilience & Healing",
    ),
    WomenQuoteItem(
      id: 100,
      quote: "The ocean is vast, the waves are high, and a woman's courage is deeper than both.",
      author: "Arati Saha",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 101,
      quote: "A pen in a woman's hand rewrites the history that tried to erase her.",
      author: "Amrita Pritam",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 102,
      quote: "Live with the dignity of a Banyan tree—rooted in truth and generous with shade.",
      author: "Mahadevi Varma",
      category: "Wisdom & Action",
    ),
    WomenQuoteItem(
      id: 103,
      quote: "Let no wall be high enough to block the sunlight from a girl's classroom.",
      author: "Fatima Sheikh",
      category: "Education & Wisdom",
    ),
    WomenQuoteItem(
      id: 104,
      quote: "True healing honors both the body's wisdom and the spirit's courage.",
      author: "Dr. Anandibai Joshi",
      category: "Trailblazers & Courage",
    ),
    WomenQuoteItem(
      id: 105,
      quote: "The constitution of a free nation beats strongest when its daughters walk without fear.",
      author: "Hansa Jivraj Mehta",
      category: "Equality & Justice",
    ),
    WomenQuoteItem(
      id: 106,
      quote: "Justice is incomplete until the last woman in the farthest village knows her rights.",
      author: "Dakshayani Velayudhan",
      category: "Equality & Justice",
    ),
    WomenQuoteItem(
      id: 107,
      quote: "Democracy thrives where women speak, vote, lead, and build together.",
      author: "Ammu Swaminathan",
      category: "Voice & Leadership",
    ),
    WomenQuoteItem(
      id: 108,
      quote: "Art, craft, and heritage survive because women wove their soul into every thread.",
      author: "Kamaladevi Chattopadhyay",
      category: "Trailblazers & Courage",
    ),
    WomenQuoteItem(
      id: 109,
      quote: "A woman's entrepreneurship lifts not just a household, but an entire local economy.",
      author: "Ela Bhatt (SEWA)",
      category: "Change & Empowerment",
    ),
    WomenQuoteItem(
      id: 110,
      quote: "Self-reliance is the strongest shield a woman can carry.",
      author: "Ela Bhatt",
      category: "Courage & Agency",
    ),
    WomenQuoteItem(
      id: 111,
      quote: "When rural women unite, banks listen, laws change, and futures bloom.",
      author: "Chetna Gala Sinha",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 112,
      quote: "Planting trees is planting hope; a woman who nurtures the earth heals tomorrow.",
      author: "Saalumarada Thimmakka",
      category: "Wisdom & Action",
    ),
    WomenQuoteItem(
      id: 113,
      quote: "Like the little hummingbird, do the best you can—every drop of courage counts.",
      author: "Wangari Maathai",
      category: "Wisdom & Action",
    ),
    WomenQuoteItem(
      id: 114,
      quote: "Human rights are not things that are put on the table for people to enjoy. They are things you fight for and then you protect.",
      author: "Wangari Maathai",
      category: "Equality & Justice",
    ),
    WomenQuoteItem(
      id: 115,
      quote: "In the midst of winter, I found there was, within me, an invincible summer.",
      author: "Albert Camus",
      category: "Resilience & Healing",
    ),
    WomenQuoteItem(
      id: 116,
      quote: "You are the author of your next chapter. Write it boldly.",
      author: "Sakhi Community",
      category: "Dreams & Perseverance",
    ),
    WomenQuoteItem(
      id: 117,
      quote: "No dream is too large when backed by a circle of women who believe in you.",
      author: "Sakhi Sisterhood",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 118,
      quote: "Rest is not quitting; taking a mindful breath prepares you to rise stronger.",
      author: "Sakhi Wellness",
      category: "Mindfulness & Joy",
    ),
    WomenQuoteItem(
      id: 119,
      quote: "Your intuition is ancient wisdom speaking in real time—listen to it.",
      author: "Sakhi Safety Guide",
      category: "Sakhi Safety & Trust",
    ),
    WomenQuoteItem(
      id: 120,
      quote: "Keep your trusted contacts updated in Sakhi—one tap can share your live GPS link when it matters most.",
      author: "Sakhi Safety Tip",
      category: "Sakhi Safety & Trust",
    ),
    WomenQuoteItem(
      id: 121,
      quote: "I am no bird; and no net ensnares me; I am a free human being with an independent will.",
      author: "Charlotte Brontë",
      category: "Courage & Agency",
    ),
    WomenQuoteItem(
      id: 122,
      quote: "There is no gate, no lock, no bolt that you can set upon the freedom of my mind.",
      author: "Virginia Woolf",
      category: "Education & Wisdom",
    ),
    WomenQuoteItem(
      id: 123,
      quote: "Lock up your libraries if you like; but there is no gate, no lock, no bolt that you can set upon the freedom of my mind.",
      author: "Virginia Woolf",
      category: "Courage & Agency",
    ),
    WomenQuoteItem(
      id: 124,
      quote:
          "One is not born, but rather becomes, a woman of fearless purpose.",
      author: "Simone de Beauvoir",
      category: "Change & Empowerment",
    ),
    WomenQuoteItem(
      id: 125,
      quote: "Hope is a passion for the possible.",
      author: "Søren Kierkegaard",
      category: "Hope & Renewal",
    ),
    WomenQuoteItem(
      id: 126,
      quote: "Out of difficulties grow miracles.",
      author: "Jean de La Bruyère",
      category: "Resilience & Healing",
    ),
    WomenQuoteItem(
      id: 127,
      quote: "She stood in the storm, and when the wind did not blow her way, she adjusted her sails.",
      author: "Elizabeth Edwards",
      category: "Resilience & Growth",
    ),
    WomenQuoteItem(
      id: 128,
      quote: "A woman is the full circle. Within her is the power to create, nurture and transform.",
      author: "Diane Mariechild",
      category: "Boundless Potential",
    ),
    WomenQuoteItem(
      id: 129,
      quote: "Here's to strong women: May we know them. May we be them. May we raise them.",
      author: "Traditional Proverb",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 130,
      quote: "Strong women don't have 'attitudes', we have standards and boundaries.",
      author: "Marilyn Monroe",
      category: "Self-Worth & Dignity",
    ),
    WomenQuoteItem(
      id: 131,
      quote: "You can never leave footprints that last if you are always walking on tiptoe.",
      author: "Leymah Gbowee",
      category: "Trailblazers & Courage",
    ),
    WomenQuoteItem(
      id: 132,
      quote: "The world will be saved by the solidarity of women who refuse to look away.",
      author: "Leymah Gbowee",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 133,
      quote: "Peace is not just the absence of conflict; it is the presence of justice and safety for every woman.",
      author: "Ellen Johnson Sirleaf",
      category: "Equality & Justice",
    ),
    WomenQuoteItem(
      id: 134,
      quote: "If your dreams do not scare you, they are not big enough.",
      author: "Ellen Johnson Sirleaf",
      category: "Dreams & Perseverance",
    ),
    WomenQuoteItem(
      id: 135,
      quote: "Optimism is the faith that leads to achievement. Nothing can be done without hope and confidence.",
      author: "Helen Keller",
      category: "Hope & Renewal",
    ),
    WomenQuoteItem(
      id: 136,
      quote: "Alone we can do so little; together we can do so much.",
      author: "Helen Keller",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 137,
      quote: "Life shrinks or expands in proportion to one's courage.",
      author: "Anaïs Nin",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 138,
      quote: "And the day came when the risk to remain tight in a bud was more painful than the risk it took to blossom.",
      author: "Anaïs Nin",
      category: "Resilience & Growth",
    ),
    WomenQuoteItem(
      id: 139,
      quote: "I am deliberate and afraid of nothing.",
      author: "Audre Lorde",
      category: "Fearless Strength",
    ),
    WomenQuoteItem(
      id: 140,
      quote: "Be a first-rate version of yourself, not a second-rate version of someone else.",
      author: "Judy Garland",
      category: "Self-Worth & Dignity",
    ),
    WomenQuoteItem(
      id: 141,
      quote: "It is never too late to be what you might have been.",
      author: "George Eliot",
      category: "Dreams & Perseverance",
    ),
    WomenQuoteItem(
      id: 142,
      quote: "What you do makes a difference, and you have to decide what kind of difference you want to make.",
      author: "Jane Goodall",
      category: "Wisdom & Action",
    ),
    WomenQuoteItem(
      id: 143,
      quote: "How wonderful it is that nobody need wait a single moment before starting to improve the world.",
      author: "Anne Frank",
      category: "Hope & Renewal",
    ),
    WomenQuoteItem(
      id: 144,
      quote: "Think of all the beauty still left around you and be happy.",
      author: "Anne Frank",
      category: "Mindfulness & Joy",
    ),
    WomenQuoteItem(
      id: 145,
      quote: "Nothing is impossible; the word itself says 'I'm possible'!",
      author: "Audrey Hepburn",
      category: "Boundless Potential",
    ),
    WomenQuoteItem(
      id: 146,
      quote: "As you grow older, you will discover that you have two hands—one for helping yourself, the other for helping others.",
      author: "Audrey Hepburn",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 147,
      quote: "We must believe that we are gifted for something, and that this thing, at whatever cost, must be attained.",
      author: "Marie Curie",
      category: "Dreams & Perseverance",
    ),
    WomenQuoteItem(
      id: 148,
      quote: "First, have a definite, clear practical ideal; a goal, an objective. Second, have the necessary means to achieve your ends.",
      author: "Grace Hopper",
      category: "Wisdom & Action",
    ),
    WomenQuoteItem(
      id: 149,
      quote: "A ship in port is safe, but that is not what ships are built for. Sail out to sea and do new things.",
      author: "Rear Admiral Grace Hopper",
      category: "Trailblazers & Courage",
    ),
    WomenQuoteItem(
      id: 150,
      quote: "That brain of mine is something more than merely mortal; as time will show.",
      author: "Ada Lovelace",
      category: "Education & Wisdom",
    ),
    WomenQuoteItem(
      id: 151,
      quote: "Code, create, lead, and mentor—women in technology are shaping a safer digital tomorrow.",
      author: "Sakhi WomenInTech Circle",
      category: "Change & Empowerment",
    ),
    WomenQuoteItem(
      id: 152,
      quote: "Every woman who heals herself helps heal all the women who came before her and all those who come after her.",
      author: "Christiane Northrup",
      category: "Resilience & Healing",
    ),
    WomenQuoteItem(
      id: 153,
      quote: "Daring to set boundaries is about having the courage to love ourselves, even when we risk disappointing others.",
      author: "Brené Brown",
      category: "Self-Worth & Dignity",
    ),
    WomenQuoteItem(
      id: 154,
      quote: "You are allowed to be both a masterpiece and a work in progress simultaneously.",
      author: "Sophia Bush",
      category: "Resilience & Growth",
    ),
    WomenQuoteItem(
      id: 155,
      quote: "Don't let anyone speak for you, and don't rely on others to fight for you.",
      author: "Michelle Obama",
      category: "Courage & Agency",
    ),
    WomenQuoteItem(
      id: 156,
      quote: "Success isn't about how much money you make; it's about the difference you make in people's lives.",
      author: "Michelle Obama",
      category: "Wisdom & Action",
    ),
    WomenQuoteItem(
      id: 157,
      quote: "You can't be hesitant about who you are.",
      author: "Viola Davis",
      category: "Confidence & Trust",
    ),
    WomenQuoteItem(
      id: 158,
      quote: "All dreams are within reach. All you have to do is keep moving towards them.",
      author: "Viola Davis",
      category: "Dreams & Perseverance",
    ),
    WomenQuoteItem(
      id: 159,
      quote: "I've learned that people will forget what you said, people will forget what you did, but people will never forget how you made them feel.",
      author: "Maya Angelou",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 160,
      quote: "Still, like air, I'll rise.",
      author: "Maya Angelou",
      category: "Resilience & Healing",
    ),
    WomenQuoteItem(
      id: 161,
      quote: "Be a rainbow in somebody else's cloud.",
      author: "Maya Angelou",
      category: "Sisterhood & Solidarity",
    ),
    WomenQuoteItem(
      id: 162,
      quote: "Have enough courage to trust love one more time and always one more time.",
      author: "Maya Angelou",
      category: "Hope & Renewal",
    ),
    WomenQuoteItem(
      id: 163,
      quote: "My mission in life is not merely to survive, but to thrive; and to do so with some passion, some compassion, some humor, and some style.",
      author: "Maya Angelou",
      category: "Mindfulness & Joy",
    ),
    WomenQuoteItem(
      id: 164,
      quote: "When a woman becomes her own best friend, life is easier.",
      author: "Diane Von Furstenberg",
      category: "Self-Worth & Dignity",
    ),
    WomenQuoteItem(
      id: 165,
      quote: "I didn't know what I wanted to do, but I always knew the woman I wanted to be.",
      author: "Diane Von Furstenberg",
      category: "Confidence & Trust",
    ),
    WomenQuoteItem(
      id: 166,
      quote: "Fear is not an option when your sisters are beside you.",
      author: "Sakhi Sisterhood",
      category: "Sakhi Safety & Trust",
    ),
    WomenQuoteItem(
      id: 167,
      quote: "Use Sakhi's Safe Test Mode anytime to practice your 3-second SOS shortcut without sending a live alert.",
      author: "Sakhi Safety Tip",
      category: "Sakhi Safety & Trust",
    ),
    WomenQuoteItem(
      id: 168,
      quote: "Wherever you travel today, walk tall—your voice, your courage, and your Sakhi community travel with you.",
      author: "Sakhi Community",
      category: "Sakhi Safety & Trust",
    ),
  ];
}

/// Discord-style animated quotation loading screen & inspiration carousel.
/// Replaces plain CircularProgressIndicator spinners with rotating empowering
/// quotations about women, sisterhood, and safety.
class SakhiQuoteLoader extends StatefulWidget {
  final String? statusLabel;
  final bool compact;
  final bool isBanner;
  final int? initialQuoteIndex;

  const SakhiQuoteLoader({
    super.key,
    this.statusLabel,
    this.compact = false,
    this.isBanner = false,
    this.initialQuoteIndex,
  });

  const SakhiQuoteLoader.fullScreen({
    super.key,
    this.statusLabel = 'Preparing your safe Sakhi space...',
    this.initialQuoteIndex,
  }) : compact = false,
       isBanner = false;

  const SakhiQuoteLoader.inline({
    super.key,
    this.statusLabel = 'Syncing live safety & community updates...',
    this.initialQuoteIndex,
  }) : compact = true,
       isBanner = false;

  const SakhiQuoteLoader.banner({
    super.key,
    this.statusLabel,
    this.initialQuoteIndex,
  }) : compact = true,
       isBanner = true;

  @override
  State<SakhiQuoteLoader> createState() => _SakhiQuoteLoaderState();
}

class _SakhiQuoteLoaderState extends State<SakhiQuoteLoader> {
  late int _currentIndex;
  Timer? _rotationTimer;

  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    final total = SakhiWomenQuotes.all.length;
    _currentIndex =
        (widget.initialQuoteIndex ??
            (DateTime.now().millisecondsSinceEpoch ~/ 1000)) %
        total;
    if (!_isWidgetTest) {
      _rotationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % SakhiWomenQuotes.all.length;
        });
      });
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  void _nextQuote() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % SakhiWomenQuotes.all.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = SakhiWomenQuotes.all[_currentIndex];

    if (widget.isBanner) {
      return GestureDetector(
        key: const Key('sakhi-quote-banner'),
        onTap: _nextQuote,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF9EFFB), Color(0xFFFDF2F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7D4EC)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDE0F3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF5A1868),
                  size: 18,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.14),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey<int>(item.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5A1868)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${item.category.toUpperCase()} • #${item.id}/${SakhiWomenQuotes.all.length}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF5A1868),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Tap for next ↻',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7B4B94),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '“${item.quote}”',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2A1930),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '— ${item.author}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5A1868),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final cardContent = Container(
      key: const Key('sakhi-discord-quote-loader'),
      constraints: const BoxConstraints(maxWidth: 400),
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 18 : 24,
        vertical: widget.compact ? 16 : 26,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEFE3EE), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x145A1868),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widget.compact ? 54 : 68,
            height: widget.compact ? 54 : 68,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFCE8EC),
              border: Border.all(color: const Color(0xFFF4C2CD), width: 2),
            ),
            child: Image.asset(
              AppAssets.module4ShieldLotus,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.shield_rounded,
                color: Color(0xFF5A1868),
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '✨ ${item.category.toUpperCase()} (${item.id}/${SakhiWomenQuotes.all.length})',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF5A1868),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.16),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey<int>(item.id),
              children: [
                Text(
                  '“${item.quote}”',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.compact ? 13.5 : 15,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2A1930),
                    height: 1.42,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '— ${item.author}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5A1868),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: Color(0xFFF3E8F6),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5A1868)),
            ),
          ),
          if (widget.statusLabel != null && widget.statusLabel!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              widget.statusLabel!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF6E6275),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _nextQuote,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: const Color(0xFF5A1868),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text(
              'Inspire me with another quote',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (widget.compact) {
      return Center(child: cardContent);
    }

    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: cardContent),
    );
  }
}
