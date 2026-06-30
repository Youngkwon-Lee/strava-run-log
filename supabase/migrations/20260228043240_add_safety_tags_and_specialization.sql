-- exercises: 전공별 안전 운동 태그 배열 (GIN 인덱스로 contains 쿼리 최적화)
ALTER TABLE exercises ADD COLUMN safety_tags TEXT[] DEFAULT '{}';
CREATE INDEX idx_exercises_safety_tags ON exercises USING GIN (safety_tags);

-- persons: 전공 (optional, config에서 관리 — CHECK 없음)
ALTER TABLE persons ADD COLUMN specialization TEXT;;
