// English card.name -> Korean display name, for showing both together
// ("Translucence (트랜스루센스)") since tarot_cards has no Korean name column.
const KO_NAMES = {
  'Light Red': '라이트 레드', 'Red': '레드', 'Dark Red': '다크 레드',
  'Light Orange': '라이트 오렌지', 'Orange': '오렌지', 'Dark Orange': '다크 오렌지',
  'Light Yellow': '라이트 옐로우', 'Yellow': '옐로우', 'Dark Yellow': '다크 옐로우',
  'Light Green': '라이트 그린', 'Green': '그린', 'Dark Green': '다크 그린',
  'Light Blue': '라이트 블루', 'Blue': '블루', 'Dark Blue': '다크 블루',
  'Light Indigo': '라이트 인디고', 'Indigo': '인디고', 'Dark Indigo': '다크 인디고',
  'Light Violet': '라이트 바이올렛', 'Violet': '바이올렛', 'Dark Violet': '다크 바이올렛',
  'Sky': '스카이', 'Pink': '핑크', 'White': '화이트', 'Gray': '그레이', 'Black': '블랙',
  'Rainbow': '레인보우', 'Various': '베리어스', 'Ocher': '오커',
  'Copper': '코퍼', 'Old Copper': '올드 코퍼', 'Turquoise': '터콰이즈',
  'Vintage': '빈티지', 'Translucence': '트랜스루센스', 'Gold': '골드', 'Silver': '실버',
};

export function koName(name) {
  return KO_NAMES[name] || null;
}

export function withKoName(name) {
  const ko = koName(name);
  return ko ? `${name} (${ko})` : name;
}
