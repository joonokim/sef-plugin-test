# Architecture Guide

## Top-Level 3-Tier

```
com.sqisoft.sef/
  core/       # Shared utilities: ApiResponse, ErrorCode, BusinessException, excel/mail/file utils
  infra/      # Cross-cutting: config, security (JWT, Spring Security), persistence, egovframe, scheduler
  modules/    # Business modules: auth, user, board, code, role, menu, menurole
```

Dependency direction: `modules` -> `core`, `modules` -> `infra`, `core` -> nothing.

## Module Internal Layers

Each module uses a flat 5-package structure:

```
modules/{name}/
  controller/    # HTTP handling, @RestController
  service/       # Interface + impl/  (business logic)
  mapper/        # MyBatis @Mapper interface (data access)
  domain/        # Entity classes (shared across all layers)
  dto/
    request/     # Inbound DTOs with @Valid
    response/    # Outbound DTOs with static from() factory
```

Dependency flow within a module:

```
controller -> service (interface) -> serviceImpl -> mapper
                                         |
                                       domain (used by all layers)
```

Domain objects are NOT isolated behind a repository boundary. Service and Mapper both work with domain objects directly.

## Object Conversion Flow

### Inbound (Create/Update)

```
HTTP Request
  -> Request DTO (@Valid)
    -> Service: Domain.create(...) or domain.update(...)
      -> Mapper.save(domain) / Mapper.update(domain)
        -> MyBatis XML -> DB
```

### Outbound (Read)

```
DB -> MyBatis XML
  -> Mapper returns Domain (mapUnderscoreToCamelCase=true)
    -> Service returns Domain
      -> Response DTO: ResponseDto.from(domain)
        -> ApiResponse.success(responseDto)
          -> HTTP Response
```

## Domain Entity Pattern

Entities use Lombok `@Getter @Builder @NoArgsConstructor @AllArgsConstructor`. Business logic lives in the entity:

```java
@Getter @Builder @NoArgsConstructor @AllArgsConstructor
public class Board {
    private Long bbsSq;
    private String menuId;
    private String bbsTtl;
    private String bbsCn;
    // ... fields

    // Factory method for creation
    public static Board create(String menuId, String title, String content, String useYn, String userId) {
        return Board.builder()
                .menuId(menuId).bbsTtl(title).bbsCn(content)
                .useYn(useYn != null ? useYn : "Y").delYn("N")
                .rgtrId(userId).regDt(LocalDateTime.now())
                .build();
    }

    // Mutation method with ownership validation
    public void update(String title, String content, String useYn, String userId) {
        validateOwner(userId);
        if (title != null) this.bbsTtl = title;
        // ...
        this.mdfrId = userId;
        this.mdfcnDt = LocalDateTime.now();
    }

    // Soft delete
    public void delete(String userId) {
        validateOwner(userId);
        this.delYn = "Y";
    }
}
```

## Response DTO Pattern

Every response DTO has a static `from(Domain)` method that converts domain to response:

```java
@Getter @Builder @NoArgsConstructor @AllArgsConstructor
public class BoardDetailResponse {
    private Long bbsSq;
    private String bbsTtl;
    // ... fields

    public static BoardDetailResponse from(Board board) {
        return BoardDetailResponse.builder()
                .bbsSq(board.getBbsSq())
                .bbsTtl(board.getBbsTtl())
                // ...
                .build();
    }
}
```

## Service Pattern

Interface + impl split. Impl extends `EgovAbstractServiceImpl`:

```java
// Interface
public interface BoardService {
    PageResponse<BoardListResponse> getBoardList(String menuId, BoardSearchRequest request);
    void registerBoard(String menuId, BoardRegisterRequest request, MultipartFile[] files, String userId);
}

// Impl
@Service
@RequiredArgsConstructor
public class BoardServiceImpl extends EgovAbstractServiceImpl implements BoardService {
    private final BoardMapper boardMapper;

    @Override
    @Transactional
    public void registerBoard(String menuId, BoardRegisterRequest request, MultipartFile[] files, String userId) {
        Board board = Board.create(menuId, request.getBbsTtl(), request.getBbsCn(), request.getUseYn(), userId);
        boardMapper.save(board);
    }
}
```

Key points:
- `@Transactional` on write methods, `@Transactional(readOnly = true)` on read methods.
- Errors thrown via `throw new BusinessException(ErrorCode.NOT_FOUND, "message")`.
- Mapper queried with `Optional<T>` + `.orElseThrow(...)` for single-entity lookups.
