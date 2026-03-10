# Spring Boot API 서버 구축 가이드

## 개요

Spring Boot를 사용한 RESTful API 서버 구축 가이드입니다.

## 프로젝트 생성

### Spring Initializr 사용

```bash
curl https://start.spring.io/starter.zip \
  -d dependencies=web,data-jpa,security,validation,lombok \
  -d bootVersion=3.2.0 \
  -d javaVersion=17 \
  -d type=maven-project \
  -d groupId=com.example \
  -d artifactId=backend \
  -o backend.zip

unzip backend.zip
cd backend
```

## 기본 구조

### Application.java

```java
package com.example.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

### REST Controller

```java
package com.example.backend.controller;

import com.example.backend.dto.request.BoardCreateRequest;
import com.example.backend.dto.response.BoardResponse;
import com.example.backend.service.BoardService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/boards")
@RequiredArgsConstructor
public class BoardController {

    private final BoardService boardService;

    @GetMapping
    public ResponseEntity<Page<BoardResponse>> getBoards(Pageable pageable) {
        Page<BoardResponse> boards = boardService.getBoards(pageable);
        return ResponseEntity.ok(boards);
    }

    @GetMapping("/{id}")
    public ResponseEntity<BoardResponse> getBoard(@PathVariable Long id) {
        BoardResponse board = boardService.getBoard(id);
        return ResponseEntity.ok(board);
    }

    @PostMapping
    public ResponseEntity<BoardResponse> createBoard(
        @Valid @RequestBody BoardCreateRequest request
    ) {
        BoardResponse board = boardService.createBoard(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(board);
    }

    @PutMapping("/{id}")
    public ResponseEntity<BoardResponse> updateBoard(
        @PathVariable Long id,
        @Valid @RequestBody BoardCreateRequest request
    ) {
        BoardResponse board = boardService.updateBoard(id, request);
        return ResponseEntity.ok(board);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteBoard(@PathVariable Long id) {
        boardService.deleteBoard(id);
        return ResponseEntity.noContent().build();
    }
}
```

### Service Layer

```java
package com.example.backend.service;

import com.example.backend.domain.Board;
import com.example.backend.dto.request.BoardCreateRequest;
import com.example.backend.dto.response.BoardResponse;
import com.example.backend.exception.BoardNotFoundException;
import com.example.backend.repository.BoardRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BoardService {

    private final BoardRepository boardRepository;

    public Page<BoardResponse> getBoards(Pageable pageable) {
        return boardRepository.findAll(pageable)
            .map(BoardResponse::from);
    }

    public BoardResponse getBoard(Long id) {
        Board board = boardRepository.findById(id)
            .orElseThrow(() -> new BoardNotFoundException(id));
        return BoardResponse.from(board);
    }

    @Transactional
    public BoardResponse createBoard(BoardCreateRequest request) {
        Board board = Board.builder()
            .title(request.getTitle())
            .content(request.getContent())
            .author(request.getAuthor())
            .build();

        Board savedBoard = boardRepository.save(board);
        return BoardResponse.from(savedBoard);
    }

    @Transactional
    public BoardResponse updateBoard(Long id, BoardCreateRequest request) {
        Board board = boardRepository.findById(id)
            .orElseThrow(() -> new BoardNotFoundException(id));

        board.update(request.getTitle(), request.getContent());
        return BoardResponse.from(board);
    }

    @Transactional
    public void deleteBoard(Long id) {
        if (!boardRepository.existsById(id)) {
            throw new BoardNotFoundException(id);
        }
        boardRepository.deleteById(id);
    }
}
```

## DTO 패턴

### Request DTO

```java
package com.example.backend.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class BoardCreateRequest {

    @NotBlank(message = "제목은 필수입니다")
    @Size(max = 100, message = "제목은 100자를 초과할 수 없습니다")
    private String title;

    @NotBlank(message = "내용은 필수입니다")
    private String content;

    @NotBlank(message = "작성자는 필수입니다")
    private String author;
}
```

### Response DTO

```java
package com.example.backend.dto.response;

import com.example.backend.domain.Board;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class BoardResponse {
    private Long id;
    private String title;
    private String content;
    private String author;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public static BoardResponse from(Board board) {
        return BoardResponse.builder()
            .id(board.getId())
            .title(board.getTitle())
            .content(board.getContent())
            .author(board.getAuthor())
            .createdAt(board.getCreatedAt())
            .updatedAt(board.getUpdatedAt())
            .build();
    }
}
```

## 예외 처리

### Custom Exception

```java
package com.example.backend.exception;

public class BoardNotFoundException extends RuntimeException {
    public BoardNotFoundException(Long id) {
        super("Board not found with id: " + id);
    }
}
```

### Global Exception Handler

```java
package com.example.backend.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BoardNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleBoardNotFound(BoardNotFoundException e) {
        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.NOT_FOUND.value())
            .error("Not Found")
            .message(e.getMessage())
            .build();

        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(error);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> handleValidationExceptions(
        MethodArgumentNotValidException e
    ) {
        Map<String, String> errors = new HashMap<>();
        e.getBindingResult().getAllErrors().forEach((error) -> {
            String fieldName = ((FieldError) error).getField();
            String errorMessage = error.getDefaultMessage();
            errors.put(fieldName, errorMessage);
        });

        return ResponseEntity.badRequest().body(errors);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGenericException(Exception e) {
        ErrorResponse error = ErrorResponse.builder()
            .timestamp(LocalDateTime.now())
            .status(HttpStatus.INTERNAL_SERVER_ERROR.value())
            .error("Internal Server Error")
            .message(e.getMessage())
            .build();

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }
}
```

## CORS 설정

```java
package com.example.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
            .allowedOrigins(
                "http://localhost:3000",
                "https://yourdomain.com"
            )
            .allowedMethods("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS")
            .allowedHeaders("*")
            .allowCredentials(true)
            .maxAge(3600);
    }
}
```

## 테스트

### Controller 테스트

```java
package com.example.backend.controller;

import com.example.backend.dto.request.BoardCreateRequest;
import com.example.backend.dto.response.BoardResponse;
import com.example.backend.service.BoardService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(BoardController.class)
class BoardControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private BoardService boardService;

    @Test
    void createBoard_Success() throws Exception {
        // given
        BoardCreateRequest request = new BoardCreateRequest();
        request.setTitle("Test Title");
        request.setContent("Test Content");
        request.setAuthor("Test Author");

        BoardResponse response = BoardResponse.builder()
            .id(1L)
            .title("Test Title")
            .content("Test Content")
            .author("Test Author")
            .build();

        when(boardService.createBoard(any())).thenReturn(response);

        // when & then
        mockMvc.perform(post("/api/boards")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1L))
            .andExpect(jsonPath("$.title").value("Test Title"));
    }
}
```

## 참고 자료

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [Spring Data JPA](https://spring.io/projects/spring-data-jpa)
- [Bean Validation](https://beanvalidation.org/)
