-- PostgreSQL Optimization Demo
-- Use EXPLAIN or EXPLAIN ANALYZE before each query to compare execution plans.

-- 1. Non-optimized query
EXPLAIN ANALYZE
SELECT
    (
        SELECT CONCAT(title, ': ', cnt)
        FROM (
            SELECT title, COUNT(*) AS cnt
            FROM (
                SELECT l.like_id, l.like_date, p.post_id, p.title, u.user_id
                FROM social_likes AS l
                JOIN social_posts AS p ON l.post_id = p.post_id
                JOIN social_users AS u ON l.user_id = u.user_id
                WHERE l.like_date > DATE '2025-01-01' AND u.account_status = 'active'
            ) AS sub1 GROUP BY title
        ) AS sub2
        WHERE cnt = (
            SELECT MIN(cnt) FROM (
                SELECT COUNT(*) AS cnt FROM (
                    SELECT l.like_id, l.like_date, p.post_id, p.title, u.user_id
                    FROM social_likes AS l
                    JOIN social_posts AS p ON l.post_id = p.post_id
                    JOIN social_users AS u ON l.user_id = u.user_id
                    WHERE l.like_date > DATE '2025-01-01' AND u.account_status = 'active'
                ) AS sub3 GROUP BY title
            ) AS sub4
        ) LIMIT 1
    ) AS min_likes,

    (
        SELECT CONCAT(title, ': ', cnt)
        FROM (
            SELECT title, COUNT(*) AS cnt
            FROM (
                SELECT l.like_id, l.like_date, p.post_id, p.title, u.user_id
                FROM social_likes AS l
                JOIN social_posts AS p ON l.post_id = p.post_id
                JOIN social_users AS u ON l.user_id = u.user_id
                WHERE l.like_date > DATE '2025-01-01' AND u.account_status = 'active'
            ) AS sub1 GROUP BY title
        ) AS sub2
        WHERE cnt = (
            SELECT MAX(cnt) FROM (
                SELECT COUNT(*) AS cnt FROM (
                    SELECT l.like_id, l.like_date, p.post_id, p.title, u.user_id
                    FROM social_likes AS l
                    JOIN social_posts AS p ON l.post_id = p.post_id
                    JOIN social_users AS u ON l.user_id = u.user_id
                    WHERE l.like_date > DATE '2025-01-01' AND u.account_status = 'active'
                ) AS sub3 GROUP BY title
            ) AS sub4
        ) LIMIT 1
    ) AS max_likes;

-- 2. Indexes for optimization
CREATE INDEX IF NOT EXISTS idx_social_likes_date ON social_likes(like_date);
CREATE INDEX IF NOT EXISTS idx_social_likes_post ON social_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_social_likes_user ON social_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_social_users_status ON social_users(account_status);

-- 3. Optimized query
EXPLAIN ANALYZE
WITH filtered_likes AS (
    SELECT p.title
    FROM social_likes AS l
    JOIN social_posts AS p ON l.post_id = p.post_id
    JOIN social_users AS u ON l.user_id = u.user_id
    WHERE l.like_date > DATE '2025-01-01'
      AND u.account_status = 'active'
),
cnt_posts AS (
    SELECT title, COUNT(*) AS cnt
    FROM filtered_likes
    GROUP BY title
),
ranked_posts AS (
    SELECT title, cnt,
        ROW_NUMBER() OVER (ORDER BY cnt ASC, title ASC) AS min_rn,
        ROW_NUMBER() OVER (ORDER BY cnt DESC, title ASC) AS max_rn
    FROM cnt_posts
)
SELECT
    MAX(CONCAT(title, ': ', cnt)) FILTER (WHERE min_rn = 1) AS min_likes_post,
    MAX(CONCAT(title, ': ', cnt)) FILTER (WHERE max_rn = 1) AS max_likes_post
FROM ranked_posts;

-- 4. Bonus task
SET enable_indexscan = OFF;
SET enable_bitmapscan = OFF;

EXPLAIN ANALYZE
WITH filtered_likes AS (
    SELECT p.title FROM social_likes AS l
    JOIN social_posts AS p ON l.post_id = p.post_id
    JOIN social_users AS u ON l.user_id = u.user_id
    WHERE l.like_date > DATE '2025-01-01' AND u.account_status = 'active'
),
cnt_posts AS ( SELECT title, COUNT(*) AS cnt FROM filtered_likes GROUP BY title ),
ranked_posts AS (
    SELECT title, cnt,
        ROW_NUMBER() OVER (ORDER BY cnt ASC, title ASC) AS min_rn,
        ROW_NUMBER() OVER (ORDER BY cnt DESC, title ASC) AS max_rn
    FROM cnt_posts
)
SELECT
    MAX(CONCAT(title, ': ', cnt)) FILTER (WHERE min_rn = 1) AS min_likes_post,
    MAX(CONCAT(title, ': ', cnt)) FILTER (WHERE max_rn = 1) AS max_likes_post
FROM ranked_posts;

SET enable_indexscan = ON;
SET enable_bitmapscan = ON;


