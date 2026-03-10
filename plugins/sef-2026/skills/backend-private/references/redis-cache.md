# Redis 캐싱 전략

## 개요

Spring Boot에서 Redis를 사용한 캐싱 전략 가이드입니다.

## 의존성 추가

### Maven (pom.xml)

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-redis</artifactId>
    </dependency>

    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-cache</artifactId>
    </dependency>
</dependencies>
```

## 설정

### application.yml

```yaml
spring:
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}
      password: ${REDIS_PASSWORD:}
      lettuce:
        pool:
          max-active: 10
          max-idle: 5
          min-idle: 2
      timeout: 3000ms

  cache:
    type: redis
    redis:
      time-to-live: 600000  # 10분 (밀리초)
      cache-null-values: false
```

### RedisConfig

```java
package com.example.backend.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.jsontype.BasicPolymorphicTypeValidator;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import java.time.Duration;

@Configuration
@EnableCaching
public class RedisConfig {

    @Bean
    public RedisTemplate<String, Object> redisTemplate(
        RedisConnectionFactory connectionFactory
    ) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(connectionFactory);

        // Key Serializer
        template.setKeySerializer(new StringRedisSerializer());
        template.setHashKeySerializer(new StringRedisSerializer());

        // Value Serializer
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule());
        objectMapper.activateDefaultTyping(
            BasicPolymorphicTypeValidator.builder()
                .allowIfBaseType(Object.class)
                .build(),
            ObjectMapper.DefaultTyping.NON_FINAL
        );

        GenericJackson2JsonRedisSerializer serializer =
            new GenericJackson2JsonRedisSerializer(objectMapper);

        template.setValueSerializer(serializer);
        template.setHashValueSerializer(serializer);

        template.afterPropertiesSet();
        return template;
    }

    @Bean
    public CacheManager cacheManager(RedisConnectionFactory connectionFactory) {
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule());
        objectMapper.activateDefaultTyping(
            BasicPolymorphicTypeValidator.builder()
                .allowIfBaseType(Object.class)
                .build(),
            ObjectMapper.DefaultTyping.NON_FINAL
        );

        GenericJackson2JsonRedisSerializer serializer =
            new GenericJackson2JsonRedisSerializer(objectMapper);

        RedisCacheConfiguration config = RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(10))
            .serializeKeysWith(
                RedisSerializationContext.SerializationPair.fromSerializer(
                    new StringRedisSerializer()
                )
            )
            .serializeValuesWith(
                RedisSerializationContext.SerializationPair.fromSerializer(serializer)
            );

        return RedisCacheManager.builder(connectionFactory)
            .cacheDefaults(config)
            .build();
    }
}
```

## 캐싱 전략

### @Cacheable (조회)

```java
package com.example.backend.service;

import com.example.backend.domain.Board;
import com.example.backend.dto.response.BoardResponse;
import com.example.backend.repository.BoardRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BoardService {

    private final BoardRepository boardRepository;

    @Cacheable(value = "boards", key = "#id", unless = "#result == null")
    public BoardResponse getBoard(Long id) {
        Board board = boardRepository.findById(id)
            .orElseThrow(() -> new BoardNotFoundException(id));
        return BoardResponse.from(board);
    }

    @Cacheable(value = "boards:list", key = "#page + ':' + #size")
    public Page<BoardResponse> getBoards(int page, int size) {
        Pageable pageable = PageRequest.of(page, size);
        return boardRepository.findAll(pageable)
            .map(BoardResponse::from);
    }
}
```

### @CachePut (수정)

```java
@CachePut(value = "boards", key = "#id")
@Transactional
public BoardResponse updateBoard(Long id, BoardCreateRequest request) {
    Board board = boardRepository.findById(id)
        .orElseThrow(() -> new BoardNotFoundException(id));

    board.update(request.getTitle(), request.getContent());
    return BoardResponse.from(board);
}
```

### @CacheEvict (삭제)

```java
@CacheEvict(value = "boards", key = "#id")
@Transactional
public void deleteBoard(Long id) {
    if (!boardRepository.existsById(id)) {
        throw new BoardNotFoundException(id);
    }
    boardRepository.deleteById(id);
}

// 모든 캐시 삭제
@CacheEvict(value = "boards", allEntries = true)
public void clearAllCache() {
    // 캐시 초기화 로직
}
```

### @Caching (복합)

```java
@Caching(
    put = @CachePut(value = "boards", key = "#result.id"),
    evict = @CacheEvict(value = "boards:list", allEntries = true)
)
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
```

## RedisTemplate 직접 사용

### 기본 CRUD

```java
package com.example.backend.service;

import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;

@Service
@RequiredArgsConstructor
public class RedisCacheService {

    private final RedisTemplate<String, Object> redisTemplate;

    public void set(String key, Object value) {
        redisTemplate.opsForValue().set(key, value);
    }

    public void setWithExpire(String key, Object value, long seconds) {
        redisTemplate.opsForValue().set(key, value, Duration.ofSeconds(seconds));
    }

    public Object get(String key) {
        return redisTemplate.opsForValue().get(key);
    }

    public void delete(String key) {
        redisTemplate.delete(key);
    }

    public Boolean hasKey(String key) {
        return redisTemplate.hasKey(key);
    }
}
```

### Hash 연산

```java
public void hashSet(String key, String hashKey, Object value) {
    redisTemplate.opsForHash().put(key, hashKey, value);
}

public Object hashGet(String key, String hashKey) {
    return redisTemplate.opsForHash().get(key, hashKey);
}

public Map<Object, Object> hashGetAll(String key) {
    return redisTemplate.opsForHash().entries(key);
}

public void hashDelete(String key, String... hashKeys) {
    redisTemplate.opsForHash().delete(key, (Object[]) hashKeys);
}
```

### List 연산

```java
public void listPush(String key, Object value) {
    redisTemplate.opsForList().rightPush(key, value);
}

public Object listPop(String key) {
    return redisTemplate.opsForList().leftPop(key);
}

public List<Object> listRange(String key, long start, long end) {
    return redisTemplate.opsForList().range(key, start, end);
}
```

### Set 연산

```java
public void setAdd(String key, Object... values) {
    redisTemplate.opsForSet().add(key, values);
}

public Set<Object> setMembers(String key) {
    return redisTemplate.opsForSet().members(key);
}

public Boolean setIsMember(String key, Object value) {
    return redisTemplate.opsForSet().isMember(key, value);
}
```

## 분산 락 (Distributed Lock)

```java
package com.example.backend.util;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class RedisLockUtil {

    private final RedisTemplate<String, Object> redisTemplate;

    public String acquireLock(String key, long timeoutSeconds) {
        String lockValue = UUID.randomUUID().toString();
        Boolean acquired = redisTemplate.opsForValue()
            .setIfAbsent(key, lockValue, Duration.ofSeconds(timeoutSeconds));

        return Boolean.TRUE.equals(acquired) ? lockValue : null;
    }

    public void releaseLock(String key, String lockValue) {
        Object currentValue = redisTemplate.opsForValue().get(key);
        if (lockValue.equals(currentValue)) {
            redisTemplate.delete(key);
        }
    }

    public <T> T executeWithLock(String lockKey, long timeoutSeconds,
                                   LockCallback<T> callback) {
        String lockValue = acquireLock(lockKey, timeoutSeconds);
        if (lockValue == null) {
            throw new RuntimeException("Failed to acquire lock");
        }

        try {
            return callback.execute();
        } finally {
            releaseLock(lockKey, lockValue);
        }
    }

    @FunctionalInterface
    public interface LockCallback<T> {
        T execute();
    }
}
```

## 캐시 전략 패턴

### Cache-Aside (Lazy Loading)

```java
public BoardResponse getBoard(Long id) {
    String cacheKey = "board:" + id;

    // 1. 캐시 확인
    BoardResponse cached = (BoardResponse) redisTemplate.opsForValue().get(cacheKey);
    if (cached != null) {
        return cached;
    }

    // 2. DB 조회
    Board board = boardRepository.findById(id)
        .orElseThrow(() -> new BoardNotFoundException(id));
    BoardResponse response = BoardResponse.from(board);

    // 3. 캐시 저장
    redisTemplate.opsForValue().set(cacheKey, response, Duration.ofMinutes(10));

    return response;
}
```

### Write-Through

```java
@Transactional
public BoardResponse createBoard(BoardCreateRequest request) {
    // 1. DB 저장
    Board board = Board.builder()
        .title(request.getTitle())
        .content(request.getContent())
        .build();
    Board savedBoard = boardRepository.save(board);

    // 2. 캐시 저장
    BoardResponse response = BoardResponse.from(savedBoard);
    String cacheKey = "board:" + savedBoard.getId();
    redisTemplate.opsForValue().set(cacheKey, response, Duration.ofMinutes(10));

    return response;
}
```

## 참고 자료

- [Spring Data Redis Documentation](https://spring.io/projects/spring-data-redis)
- [Redis Documentation](https://redis.io/documentation)
- [Lettuce Documentation](https://lettuce.io/)
