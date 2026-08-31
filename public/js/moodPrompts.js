// Large pool of mood prompts. A random subset (in random order) is shown
// each time the home screen loads, per user request.
export const MOOD_POOL = [
  { ic: '\u{1F62A}', text: '혼자인 것 같아 외로워요' },
  { ic: '\u{1F5FA}️', text: '앞길이 막막하게 느껴져요' },
  { ic: '\u{1F49E}', text: '누군가가 그리워요' },
  { ic: '\u{1F33F}', text: '작은 것에도 감사함을 느껴요' },
  { ic: '\u{1F337}', text: '불안하고 초조한 마음이에요' },
  { ic: '\u{1F331}', text: '변화가 필요한 것 같아요' },
  { ic: '\u{1F494}', text: '관계가 힘들게 느껴져요' },
  { ic: '\u{1F504}', text: '뭔가를 잃은 것 같아요' },
  { ic: '\u{1F525}', text: '열정이 다시 타오르고 있어요' },
  { ic: '\u{1F62B}', text: '지치고 피곤한 하루예요' },
  { ic: '\u{2728}', text: '설레지만 두렵기도 해요' },
  { ic: '\u{1F3E1}', text: '편안하고 안정된 기분이에요' },
  { ic: '\u{1F914}', text: '결정을 못 내리고 있어요' },
  { ic: '\u{1F622}', text: '슬픔이 마음에 머물러요' },
  { ic: '\u{1F600}', text: '오늘 많이 기뻤어요' },
  { ic: '\u{1F624}', text: '화가 나고 억울해요' },
  { ic: '\u{1F30C}', text: '공허하고 멍한 느낌이에요' },
  { ic: '\u{1F91D}', text: '누군가에게 위로받고 싶어요' },
  { ic: '\u{1F4AA}', text: '용기를 내고 싶은 순간이에요' },
  { ic: '\u{1F4B8}', text: '돈과 미래가 걱정돼요' },
  { ic: '\u{1F3E2}', text: '일과 진로에 대해 고민이에요' },
  { ic: '\u{2764}️', text: '사랑하는 사람이 떠올라요' },
  { ic: '\u{1F573}️', text: '무언가를 정리하고 싶어요' },
  { ic: '\u{1F31F}', text: '새로운 시작을 앞두고 있어요' },
  { ic: '\u{1F32B}️', text: '생각이 많고 복잡해요' },
  { ic: '\u{1F64F}', text: '감사한 마음을 전하고 싶어요' },
  { ic: '\u{1F98B}', text: '자유롭고 싶은 기분이에요' },
  { ic: '\u{1F9F8}', text: '위로가 필요한 하루예요' },
  { ic: '\u{26A1}', text: '갑자기 답답함이 밀려와요' },
  { ic: '\u{1F33C}', text: '평범한 오늘이 소중하게 느껴져요' },
];

// Fisher–Yates shuffle
function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function pickRandomMoods(count = 8) {
  return shuffle(MOOD_POOL).slice(0, count);
}
