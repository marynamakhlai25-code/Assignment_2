import uuid
import random
from datetime import datetime, timedelta
import psycopg2
from psycopg2.extras import execute_values
from faker import Faker

# Налаштування підключення
HOST = 'localhost'
USER = 'macbook'
PASSWORD = '1'
DATABASE = 'opt_db'
PORT = '5432'

USERS_COUNT = 100_000
POSTS_COUNT = 1_000
LIKES_COUNT = 1_000_000
CHUNK_SIZE = 10_000

fake = Faker()

def insert_users(cursor):
    print("Inserting into social_users")
    query = """
        INSERT INTO social_users (user_id, username, email, country, account_status)
        VALUES %s
    """
    user_ids = []
    for start in range(0, USERS_COUNT, CHUNK_SIZE):
        chunk = min(CHUNK_SIZE, USERS_COUNT - start)
        data = [
            (str(uuid.uuid4()), fake.user_name(), fake.email(), fake.country(), random.choice(["active", "suspended"]))
            for _ in range(chunk)
        ]
        user_ids.extend([row[0] for row in data])
        execute_values(cursor, query, data)
        print(f"Inserted {start + chunk} users...")
    return user_ids

def insert_posts(cursor):
    print("Inserting into social_posts...")
    query = """
        INSERT INTO social_posts (title, category, content)
        VALUES %s RETURNING post_id
    """
    categories = ['Tech', 'Life', 'Travel', 'Food', 'Music']
    data = [(fake.sentence(), random.choice(categories), fake.text()) for _ in range(POSTS_COUNT)]
    execute_values(cursor, query, data)
    return [row[0] for row in cursor.fetchall()]

def insert_likes(cursor, user_ids, post_ids):
    print("Inserting into social_likes...")
    query = """
        INSERT INTO social_likes (like_date, user_id, post_id)
        VALUES %s
    """
    start_date = datetime.now() - timedelta(days=365 * 3) # Лайки за останні 3 роки
    for start in range(0, LIKES_COUNT, CHUNK_SIZE):
        chunk = min(CHUNK_SIZE, LIKES_COUNT - start)
        data = [
            (start_date + timedelta(days=random.randint(0, 365 * 3)), random.choice(user_ids), random.choice(post_ids))
            for _ in range(chunk)
        ]
        execute_values(cursor, query, data)
        print(f"Inserted {start + chunk} likes...")

def main():
    connection = psycopg2.connect(host=HOST, user=USER, password=PASSWORD, dbname=DATABASE, port=PORT)
    try:
        with connection:
            with connection.cursor() as cursor:
                user_ids = insert_users(cursor)
                post_ids = insert_posts(cursor)
                insert_likes(cursor, user_ids, post_ids)
    finally:
        connection.close()

if __name__ == "__main__":
    main()