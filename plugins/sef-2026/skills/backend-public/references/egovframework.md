# eGovFrame Integration Reference

eGovFrame (Korean e-Government Standard Framework) is the mandated framework for Korean public-sector projects. This project uses eGovFrame 4.1 on top of Spring Boot 2.7.

## Rule 1: @Mapper Annotation

MUST use the eGovFrame Mapper annotation, NOT the MyBatis one.

```java
// CORRECT
import org.egovframe.rte.psl.dataaccess.mapper.Mapper;

@Mapper("boardMapper")
public interface BoardMapper { ... }

// WRONG - DO NOT USE
import org.apache.ibatis.annotations.Mapper;
```

- Always specify the bean name string: `@Mapper("moduleNameMapper")`
- No `@MapperScan` is used anywhere in the project.
- `MapperConfigurer` in `infra/persistence/config/MapperConfig.java` scans `com.sqisoft.sef.modules` for `@Mapper`-annotated interfaces and binds them to `sqlSessionFactory`.
- `SefEgovConfigAppCommon` provides `@ComponentScan(basePackages = "com.sqisoft")` which picks up `@Service`, `@Repository`, `@Component` beans.

## Rule 2: EgovAbstractServiceImpl

All service implementations MUST extend `EgovAbstractServiceImpl`.

```java
import org.egovframe.rte.fdl.cmmn.EgovAbstractServiceImpl;

@Slf4j
@Service
@RequiredArgsConstructor
public class BoardServiceImpl extends EgovAbstractServiceImpl implements BoardService {
	private final BoardMapper boardMapper;
	// ...
}
```

- Every service MUST have an interface + impl separation: `BoardService` (interface) and `BoardServiceImpl` (class).
- ServiceImpl injects Mapper directly. No Repository layer, no Vo layer.
- Use `@Slf4j` and `@RequiredArgsConstructor` from Lombok.

## Rule 3: Swagger Annotations

All controllers MUST have Swagger annotations from `io.swagger.v3.oas.annotations`.

```java
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

@Tag(name = "게시판", description = "게시물 CRUD API")
@RestController
@RequestMapping("/api/v1/menus/{menuId}/boards")
public class BoardController {

	@Operation(summary = "게시물 목록 조회", description = "메뉴별 게시물 목록을 조회합니다.")
	@GetMapping
	public ResponseEntity<ApiResponse<PageResponse<BoardListResponse>>> getBoardList(...) { ... }
}
```

- `@Tag` on the class with `name` and `description`.
- `@Operation` on every public endpoint method with `summary` and `description`.
- Swagger is only active in `local` and `dev` profiles (`@Profile({"local", "dev"})` on `SwaggerConfig`).

## Combined Example

```java
// --- Mapper ---
package com.sqisoft.sef.modules.example.mapper;

import org.egovframe.rte.psl.dataaccess.mapper.Mapper;
import java.util.List;

@Mapper("exampleMapper")
public interface ExampleMapper {
	List<Example> findAll();
	void save(Example example);
}

// --- Service Interface ---
package com.sqisoft.sef.modules.example.service;

public interface ExampleService {
	List<ExampleResponse> getList();
}

// --- Service Impl ---
package com.sqisoft.sef.modules.example.service.impl;

import org.egovframe.rte.fdl.cmmn.EgovAbstractServiceImpl;

@Slf4j
@Service
@RequiredArgsConstructor
public class ExampleServiceImpl extends EgovAbstractServiceImpl implements ExampleService {
	private final ExampleMapper exampleMapper;

	@Override
	@Transactional(readOnly = true)
	public List<ExampleResponse> getList() {
		return exampleMapper.findAll().stream()
				.map(ExampleResponse::from)
				.collect(Collectors.toList());
	}
}

// --- Controller ---
package com.sqisoft.sef.modules.example.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

@Tag(name = "예제", description = "예제 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/examples")
public class ExampleController {
	private final ExampleService exampleService;

	@Operation(summary = "목록 조회", description = "예제 목록을 조회합니다.")
	@GetMapping
	public ResponseEntity<ApiResponse<List<ExampleResponse>>> getList() {
		return ResponseEntity.ok(ApiResponse.success(exampleService.getList()));
	}
}
```

## Bean Validation Annotations

Request DTO에 사용할 수 있는 제약 어노테이션은 다음으로 제한한다:

| Annotation | Purpose |
|------------|---------|
| `@NotEmpty` | null 또는 빈 문자열 불가 |
| `@NotBlank` | null, 빈 문자열, 공백만 있는 문자열 불가 |
| `@NotNull` | null 불가 |
| `@Size` | 문자열/컬렉션 크기 제한 |
| `@Pattern` | 정규식 패턴 매칭 |

- 위 5개 어노테이션만 사용한다. 다른 제약 어노테이션이 필요한 경우 팀 합의 후 추가.
- Controller 파라미터에 `@Valid`를 반드시 붙여 DTO를 검증한다.

```java
// Request DTO example
@Getter
public class ExampleRegisterRequest {
    @NotBlank
    @Size(max = 100)
    private String title;

    @NotNull
    private String content;

    @Pattern(regexp = "^[YN]$")
    private String useYn;
}

// Controller parameter
@PostMapping
public ResponseEntity<ApiResponse<Void>> create(
        @Valid @RequestPart("data") ExampleRegisterRequest request) { ... }
```

## Checklist

- [ ] Mapper uses `org.egovframe.rte.psl.dataaccess.mapper.Mapper` with bean name string
- [ ] ServiceImpl extends `EgovAbstractServiceImpl`
- [ ] Service has interface + impl separation
- [ ] Controller has `@Tag` on class and `@Operation` on every method
- [ ] All responses wrapped in `ApiResponse<T>` via `ApiResponse.success(data)`
- [ ] Errors thrown as `BusinessException(ErrorCode.XXX, "message")`
- [ ] Request DTO validation annotations limited to: `@NotEmpty`, `@NotBlank`, `@NotNull`, `@Size`, `@Pattern`
