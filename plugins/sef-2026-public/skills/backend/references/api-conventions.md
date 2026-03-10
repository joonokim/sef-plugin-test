# API Conventions

## HTTP Method Constraint

Only GET and POST are allowed -- government network firewalls block PUT, PATCH, DELETE.

## CRUD Mapping

| Operation | Method | URL Pattern | Example |
|-----------|--------|-------------|---------|
| List | GET | `/api/v1/{resources}` | `GET /api/v1/menus/{menuId}/boards` |
| Detail | GET | `/api/v1/{resources}/{id}` | `GET /api/v1/menus/{menuId}/boards/{bbsSq}` |
| Create | POST | `/api/v1/{resources}` | `POST /api/v1/menus/{menuId}/boards` |
| Update | POST | `/api/v1/{resources}/{id}/update` | `POST /api/v1/menus/{menuId}/boards/{bbsSq}/update` |
| Delete | POST | `/api/v1/{resources}/{id}/delete` | `POST /api/v1/menus/{menuId}/boards/{bbsSq}/delete` |
| Action | POST | `/api/v1/{resources}/{id}/{action}` | `POST /api/v1/users/{id}/reset-password` |
| Batch | POST | `/api/v1/{resources}/batch-{action}` | `POST /api/v1/codes/batch-update` |

## URL Pattern Rules

- Base path: `/api/v1/`
- Resource names: plural, kebab-case
- Nested resources: `/api/v1/{parent}/{parentId}/{child}`
- Update suffix: `/{id}/update` (not PUT)
- Delete suffix: `/{id}/delete` (not DELETE)
- Sub-resource actions: `/{id}/files/{fileId}/download`
- Admin endpoints: separate controller with `/adm/v1/` prefix

## Controller Example (Board)

```java
@Tag(name = "Board", description = "Board CRUD API")
@Slf4j
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/menus/{menuId}/boards")
public class BoardController {

    private final BoardService boardService;

    @Operation(summary = "List boards")
    @GetMapping
    @PreAuthorize("hasMenuAuthority(#menuId, 'R')")
    public ResponseEntity<ApiResponse<PageResponse<BoardListResponse>>> getBoardList(
            @PathVariable String menuId,
            @ModelAttribute BoardSearchRequest request) {
        PageResponse<BoardListResponse> response = boardService.getBoardList(menuId, request);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @Operation(summary = "Get board detail")
    @GetMapping("/{bbsSq}")
    @PreAuthorize("hasMenuAuthority(#menuId, 'R')")
    public ResponseEntity<ApiResponse<BoardDetailResponse>> getBoardDetail(
            @PathVariable String menuId, @PathVariable Long bbsSq) {
        BoardDetailResponse response = boardService.getBoardDetail(menuId, bbsSq);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @Operation(summary = "Create board")
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("isAuthenticated() and hasMenuAuthority(#menuId, 'C')")
    public ResponseEntity<ApiResponse<Void>> createBoard(
            @PathVariable String menuId,
            @Valid @RequestPart("boardData") BoardRegisterRequest request,
            @RequestPart(value = "files", required = false) MultipartFile[] files,
            @AuthenticationPrincipal SecurityUser user) {
        boardService.registerBoard(menuId, request, files, user.getUserId());
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(HttpStatus.CREATED));
    }

    @Operation(summary = "Update board")
    @PostMapping(value = "/{bbsSq}/update", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("isAuthenticated() and hasMenuAuthority(#menuId, 'U')")
    public ResponseEntity<ApiResponse<BoardDetailResponse>> updateBoard(
            @PathVariable String menuId, @PathVariable Long bbsSq,
            @Valid @RequestPart("boardData") BoardUpdateRequest request,
            @RequestPart(value = "files", required = false) MultipartFile[] files,
            @AuthenticationPrincipal SecurityUser user) {
        BoardDetailResponse response = boardService.updateBoard(menuId, bbsSq, request, files, user.getUserId());
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @Operation(summary = "Delete board")
    @PostMapping("/{bbsSq}/delete")
    @PreAuthorize("isAuthenticated() and hasMenuAuthority(#menuId, 'D')")
    public ResponseEntity<ApiResponse<Void>> deleteBoard(
            @PathVariable String menuId, @PathVariable Long bbsSq,
            @AuthenticationPrincipal SecurityUser user) {
        boardService.deleteBoard(menuId, bbsSq, user.getUserId());
        return ResponseEntity.ok(ApiResponse.success());
    }
}
```

## Checklist

- Use only `@GetMapping` and `@PostMapping` -- never `@PutMapping`, `@PatchMapping`, `@DeleteMapping`
- Update/delete operations use POST with `/{id}/update` or `/{id}/delete` suffix
- All responses wrapped in `ResponseEntity<ApiResponse<T>>`
- Create returns `HttpStatus.CREATED`; read/update/delete return `HttpStatus.OK`
- Annotate every controller with `@Tag` and every method with `@Operation`
