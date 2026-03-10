# JPA/Hibernate 설정 및 사용법

## 개요

Spring Data JPA를 사용한 데이터베이스 접근 가이드입니다.

## 의존성 추가

### Maven (pom.xml)

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>

    <dependency>
        <groupId>org.postgresql</groupId>
        <artifactId>postgresql</artifactId>
        <scope>runtime</scope>
    </dependency>

    <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <optional>true</optional>
    </dependency>
</dependencies>
```

## 설정

### application.yml

```yaml
spring:
  datasource:
    driver-class-name: org.postgresql.Driver
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:mydb}
    username: ${DB_USER:user}
    password: ${DB_PASSWORD:password}
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000

  jpa:
    hibernate:
      ddl-auto: validate  # 운영: validate, 개발: update
    show-sql: false
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true
        use_sql_comments: true
        default_batch_fetch_size: 100
    open-in-view: false  # OSIV 비활성화 (권장)

logging:
  level:
    org.hibernate.SQL: DEBUG
    org.hibernate.type.descriptor.sql.BasicBinder: TRACE
```

## Entity 작성

### 기본 Entity

```java
package com.example.backend.domain;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Entity
@Table(name = "boards")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@EntityListeners(AuditingEntityListener.class)
public class Board {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 100)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(nullable = false, length = 50)
    private String author;

    @CreatedDate
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(nullable = false)
    private LocalDateTime updatedAt;

    @Builder
    public Board(String title, String content, String author) {
        this.title = title;
        this.content = content;
        this.author = author;
    }

    public void update(String title, String content) {
        this.title = title;
        this.content = content;
    }
}
```

### 연관관계 매핑

#### One-to-Many

```java
package com.example.backend.domain;

import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "users")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String name;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Board> boards = new ArrayList<>();

    @Builder
    public User(String email, String name) {
        this.email = email;
        this.name = name;
    }

    public void addBoard(Board board) {
        boards.add(board);
        board.setUser(this);
    }

    public void removeBoard(Board board) {
        boards.remove(board);
        board.setUser(null);
    }
}
```

```java
// Board 엔티티에 추가
@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(name = "user_id", nullable = false)
private User user;

void setUser(User user) {
    this.user = user;
}
```

#### Many-to-Many

```java
package com.example.backend.domain;

import jakarta.persistence.*;
import lombok.*;

import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "tags")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Tag {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String name;

    @ManyToMany(mappedBy = "tags")
    private Set<Board> boards = new HashSet<>();

    @Builder
    public Tag(String name) {
        this.name = name;
    }
}
```

```java
// Board 엔티티에 추가
@ManyToMany
@JoinTable(
    name = "board_tags",
    joinColumns = @JoinColumn(name = "board_id"),
    inverseJoinColumns = @JoinColumn(name = "tag_id")
)
private Set<Tag> tags = new HashSet<>();

public void addTag(Tag tag) {
    tags.add(tag);
    tag.getBoards().add(this);
}

public void removeTag(Tag tag) {
    tags.remove(tag);
    tag.getBoards().remove(this);
}
```

## Repository

### 기본 Repository

```java
package com.example.backend.repository;

import com.example.backend.domain.Board;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface BoardRepository extends JpaRepository<Board, Long> {

    // 메서드 이름으로 쿼리 생성
    List<Board> findByAuthor(String author);

    Page<Board> findByTitleContaining(String keyword, Pageable pageable);

    // JPQL 사용
    @Query("SELECT b FROM Board b WHERE b.title LIKE %:keyword% OR b.content LIKE %:keyword%")
    List<Board> searchByKeyword(@Param("keyword") String keyword);

    // Native Query
    @Query(value = "SELECT * FROM boards WHERE author = :author ORDER BY created_at DESC",
           nativeQuery = true)
    List<Board> findByAuthorNative(@Param("author") String author);

    // Fetch Join으로 N+1 문제 해결
    @Query("SELECT DISTINCT b FROM Board b LEFT JOIN FETCH b.tags WHERE b.id = :id")
    Board findByIdWithTags(@Param("id") Long id);
}
```

### Custom Repository

```java
package com.example.backend.repository;

import com.example.backend.domain.Board;
import java.util.List;

public interface BoardRepositoryCustom {
    List<Board> searchBoards(String keyword, String author);
}
```

```java
package com.example.backend.repository;

import com.example.backend.domain.Board;
import com.example.backend.domain.QBoard;
import com.querydsl.core.types.dsl.BooleanExpression;
import com.querydsl.jpa.impl.JPAQueryFactory;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class BoardRepositoryCustomImpl implements BoardRepositoryCustom {

    private final JPAQueryFactory queryFactory;

    @Override
    public List<Board> searchBoards(String keyword, String author) {
        QBoard board = QBoard.board;

        return queryFactory
            .selectFrom(board)
            .where(
                titleContains(keyword),
                authorEq(author)
            )
            .orderBy(board.createdAt.desc())
            .fetch();
    }

    private BooleanExpression titleContains(String keyword) {
        return keyword != null ? QBoard.board.title.contains(keyword) : null;
    }

    private BooleanExpression authorEq(String author) {
        return author != null ? QBoard.board.author.eq(author) : null;
    }
}
```

## Auditing 설정

### JpaConfig

```java
package com.example.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@Configuration
@EnableJpaAuditing
public class JpaConfig {
}
```

### BaseEntity

```java
package com.example.backend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.MappedSuperclass;
import lombok.Getter;
import org.springframework.data.annotation.CreatedBy;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedBy;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@Getter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

    @CreatedDate
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(nullable = false)
    private LocalDateTime updatedAt;

    @CreatedBy
    @Column(updatable = false, length = 50)
    private String createdBy;

    @LastModifiedBy
    @Column(length = 50)
    private String lastModifiedBy;
}
```

## 성능 최적화

### Batch Insert

```java
@Transactional
public void saveBulk(List<Board> boards) {
    for (int i = 0; i < boards.size(); i++) {
        boardRepository.save(boards.get(i));
        if (i % 100 == 0) {
            entityManager.flush();
            entityManager.clear();
        }
    }
}
```

### Fetch Join

```java
@Query("SELECT b FROM Board b LEFT JOIN FETCH b.user LEFT JOIN FETCH b.tags")
List<Board> findAllWithUserAndTags();
```

### @EntityGraph

```java
@EntityGraph(attributePaths = {"user", "tags"})
List<Board> findAll();
```

## 참고 자료

- [Spring Data JPA Documentation](https://spring.io/projects/spring-data-jpa)
- [Hibernate Documentation](https://hibernate.org/orm/documentation/)
- [QueryDSL](http://querydsl.com/)
