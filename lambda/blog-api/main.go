package main

import (
	"github.com/aws/aws-lambda-go/lambda"
	_ "github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
	"log"
	"os"
	"strconv"
	"strings"
)

type DataRequest struct {
	Sort   string `json:"sort"`
	Limit  string `json:"limit"`
	PostId string `json:"postId"`
}

type Response struct {
	StatusCode int    `json:"statusCode"`
	Message    string `json:"message"`
	Count      int    `json:"count"`
	Posts      []Post `json:"posts"`
}

type Post struct {
	Id          int    `db:"id" json:"id"`
	Title       string `db:"title" json:"title"`
	Teaser      string `db:"teaser" json:"teaser"`
	TeaserImage string `db:"teaser_image" json:"teaser_image"`
	HeaderImage string `db:"header_image" json:"header_image"`
	PublishedAt string `db:"published_at" json:"published_at"`
	UpdatedAt   string `db:"updated_at" json:"updated_at"`
	Content     string `db:"content" json:"content"`
}

var (
	selectById      = `SELECT id, title, teaser, teaser_image, header_image, published_at, updated_at, content FROM posts WHERE id = ?`
	selectByFilters = `SELECT id, title, published_at, updated_at, content FROM posts`
)

func GetPostById(db *sqlx.DB, postId string) (Response, error) {
	var posts []Post
	err := db.Select(&posts, selectById, postId)
	if err != nil {
		log.Println("Error querying database: ", err)
		return Response{
			StatusCode: 500,
			Message:    "Error querying database",
			Count:      0,
			Posts:      []Post{},
		}, nil
	}

	var statusCode = 404
	var message = "Post not found"
	var count = 0

	if len(posts) > 0 {
		statusCode = 200
		message = "Success"
		count = 1
	}

	return Response{
		StatusCode: statusCode,
		Message:    message,
		Count:      count,
		Posts:      posts,
	}, nil
}

func GetPosts(db *sqlx.DB, req DataRequest) (Response, error) {
	// Default query
	var query = selectByFilters

	// Check for valid sort parameter if exists
	if req.Sort != "" {
		var validSort = false
		if req.Sort == "asc" || req.Sort == "desc" {
			validSort = true
			query += ` ORDER BY published_at ` + strings.ToUpper(req.Sort)
		}

		// Reject invalid sort parameter
		if !validSort {
			return Response{
				StatusCode: 400,
				Message:    "Invalid sort",
				Count:      0,
				Posts:      []Post{},
			}, nil
		}
	}

	// Check for valid limit parameter if exists
	if req.Limit != "" {
		var validLimit = false
		if len(req.Limit) > 0 && len(req.Limit) < 4 {
			limitAsInt, err := strconv.Atoi(req.Limit)
			if err != nil {
				log.Println("Error converting limit to int: ", err)
			} else {
				if limitAsInt > 0 && limitAsInt < 10001 {
					limitAsString := strconv.Itoa(limitAsInt)
					query += ` LIMIT ` + limitAsString
					validLimit = true
				}
			}
		}

		// Reject invalid limit parameter
		if !validLimit {
			return Response{
				StatusCode: 400,
				Message:    "Invalid limit",
				Count:      0,
				Posts:      []Post{},
			}, nil
		}
	}

	// Default response values
	var statusCode = 404
	var message = "No posts found"
	var count = 0

	var posts []Post
	err := db.Select(&posts, query)
	if err != nil {
		log.Println("Error querying database: ", err)
		return Response{
			StatusCode: 500,
			Message:    "Error querying database",
			Count:      0,
			Posts:      []Post{},
		}, nil
	}

	// Set response values if posts are found
	if len(posts) > 0 {
		statusCode = 200
		message = "Success"
		count = len(posts)
	}

	return Response{
		StatusCode: statusCode,
		Message:    message,
		Count:      count,
		Posts:      posts,
	}, nil

}

func handler(req DataRequest) (Response, error) {
	db, err := sqlx.Open("mysql", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Println("Error connecting to database: ", err)
		return Response{
			StatusCode: 500,
			Message:    "Error connecting to database",
			Posts:      []Post{},
		}, nil
	}
	defer func(db *sqlx.DB) {
		err := db.Close()
		if err != nil {
			log.Println("Error closing database: ", err)
		}
	}(db)

	// Get 1 post by id
	if req.PostId != "" {
		log.Println("Post id provided")
		return GetPostById(db, req.PostId)
	}

	// Get more than 1 post with optional sort and limit parameters
	return GetPosts(db, req)
}

func main() {
	lambda.Start(handler)
}
