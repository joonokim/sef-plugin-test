# Excel Export Reference

Apache POI-based Excel export utility using annotation-driven column mapping and streaming workbooks.

---

## Overview

The excel export system consists of:

| Component | Location | Role |
|---|---|---|
| `@ExcelHeader` | `core/utils/excel/annotation/` | Marks DTO fields as Excel columns |
| `ExcelHeaderDto` | `core/utils/excel/dto/` | Internal column metadata (sort-aware) |
| `ExcelSheetDto<T>` | `core/utils/excel/dto/` | Bundles sheet name + data + headers for multi-DTO export |
| `ExcelSupportV1` | `core/utils/excel/util/` | Interface: connect / draw / download |
| `ExcelUtilsV1` | `core/utils/excel/util/impl/` | Spring `@Component` implementation |

Flow summary: annotate DTO fields → call `connect()` → call a `draw*()` method → call `downloadExcelFile()`.

---

## `@ExcelHeader` Annotation

Applied to fields in response DTOs. Retained at runtime (`RUNTIME`), target is `FIELD`.

```java
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
public @interface ExcelHeader {
    int    sheetIndex();        // 1-based sheet number; default 1
    String groupHeaderName();   // row-0 group header label (merged across grouped columns)
    int    groupHeaderOrder();  // sort order of the group; default 0
    String headerName();        // row-1 column header label
    int    headerOrder();       // sort order within the group; default 0
    int    columnWidth();       // column width in character units; default 15
}
```

### Field descriptions

| Field | Type | Default | Purpose |
|---|---|---|---|
| `sheetIndex` | `int` | `1` | Which sheet this column belongs to (1-based). Used by `drawMultipleSheetsFromSingleDto`. |
| `groupHeaderName` | `String` | — | Label for the merged group-header row (row 0). Columns sharing the same value are merged into one cell. |
| `groupHeaderOrder` | `int` | `0` | Left-to-right ordering of groups. |
| `headerName` | `String` | — | Label for the column header row (row 1). |
| `headerOrder` | `int` | `0` | Left-to-right ordering of columns within a group. |
| `columnWidth` | `int` | `15` | Width passed to `sheet.setColumnWidth(col, value * 256)`. |

### Sort order

`ExcelHeaderDto` implements `Comparable`. Columns are sorted by: `sheetIndex` → `groupHeaderOrder` → `headerOrder`.

---

## `ExcelSupportV1` Interface

```java
public interface ExcelSupportV1 {

    // 1. Bind the HTTP response and initialise a new SXSSFWorkbook
    void connect(HttpServletResponse response);

    // 2a. Single sheet — one DTO class, one sheet
    <T> void drawSheet(String sheetName, Class<T> clazz, List<T> data);

    // 2b. Multi-sheet from ONE DTO class — sheetIndex on @ExcelHeader drives sheet assignment
    <T> void drawMultipleSheetsFromSingleDto(List<String> sheetNames, Class<T> clazz, List<T> data);

    // 2c. Multi-sheet from DIFFERENT DTO classes — each ExcelSheetDto carries its own class + data
    void drawMultipleSheetsFromDifferentDtos(List<ExcelSheetDto<?>> sheetList);

    // 3. Write workbook to response stream and clean up ThreadLocal state
    void downloadExcelFile(String fileName);
}
```

Always call the methods in this order: `connect` → one `draw*` → `downloadExcelFile`.

---

## `ExcelUtilsV1` Implementation Details

### ThreadLocal state

```java
private final ThreadLocal<SXSSFWorkbook> workbookHolder = new ThreadLocal<>();
private final ThreadLocal<HttpServletResponse> responseHolder = new ThreadLocal<>();
```

Each request thread gets its own `SXSSFWorkbook` instance via `connect()`. Both holders are removed in the `finally` block of `downloadExcelFile()`, preventing memory leaks across requests.

### SXSSFWorkbook (streaming)

```java
workbookHolder.set(new SXSSFWorkbook(-1)); // -1 = keep all rows in memory until explicit flush
```

After writing each sheet, rows are flushed to disk:

```java
private static final int MAX_ROW = 5000;
// ...
sheet.flushRows(MAX_ROW); // flush rows to temp file, keeping last MAX_ROW in memory
```

This makes large exports viable without OOM errors.

### Sheet layout

```
Row 0  — Group header row   (height: 600 units, cells merged per group)
Row 1  — Column header row  (height: 400 units)
Row 2+ — Data rows          (height: 350 units)
Col 0  — Auto-injected "구분 / 일련번호" sequence column (1-based row number)
Col 1+ — DTO fields in annotation-defined order
```

### Header styling

Group headers cycle through four background colours in order:

```java
private static final short[] GROUP_HEADER_BACKGROUND_COLORS = {
    IndexedColors.LIGHT_YELLOW.getIndex(),
    IndexedColors.LIGHT_GREEN.getIndex(),
    IndexedColors.LIGHT_TURQUOISE.getIndex(),
    IndexedColors.LIGHT_BLUE.getIndex(),
};
```

The sequence column ("구분") uses `GREY_25_PERCENT`. Headers use `BorderStyle.MEDIUM`; data cells use `BorderStyle.THIN`.

### Cell value type mapping

`setCellValueByType()` handles: `String`, `Integer`, `Long`, `Double`, `Boolean`, and falls back to `toString()` for other types. `null` writes an empty string.

### File download headers

```java
response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
response.setHeader("Content-Disposition", "attachment; filename*=UTF-8''" + encodedFileName);
response.setHeader("Access-Control-Expose-Headers", "Content-Disposition");
```

The filename is URL-encoded with `+` replaced by `%20`. The `.xlsx` extension is appended automatically.

---

## Single Sheet Export Flow

1. `connect(response)` — creates `SXSSFWorkbook`, stores both objects in `ThreadLocal`.
2. `drawSheet(sheetName, clazz, data)`:
   - Reflects over `clazz`, collects all `@ExcelHeader`-annotated fields into sorted `ExcelHeaderDto` list.
   - Prepends the sequence column.
   - Creates the sheet, writes row 0 (group headers, merged), row 1 (column headers), rows 2+ (data).
   - Calls `sheet.flushRows(5000)`.
   - Clears the data list (`data.clear()`).
3. `downloadExcelFile(fileName)` — writes workbook to response output stream, calls `workbook.dispose()`, removes `ThreadLocal` entries.

---

## Multi-Sheet Export Flow

### From a single DTO (`drawMultipleSheetsFromSingleDto`)

Use this when one DTO class covers all sheets, differentiated by `sheetIndex` on `@ExcelHeader`.

1. `extractSheetHeaderMap(clazz)` groups all annotated fields by `sheetIndex` into a `LinkedHashMap<Integer, List<ExcelHeaderDto>>`.
2. For each `sheetIndex` entry, the matching sheet name is looked up from the `sheetNames` list (0-based: `sheetNames.get(sheetIndex - 1)`).
3. `sheetIndex` is stripped from the headers (reset to `0`) before calling `createSheet`, so the existing single-sheet logic is reused.
4. All sheets receive the same full `data` list; the column set per sheet is determined by which `@ExcelHeader` fields carry that `sheetIndex`.

### From different DTOs (`drawMultipleSheetsFromDifferentDtos`)

Use this when each sheet has a completely different structure.

1. Build a `List<ExcelSheetDto<?>>` manually — each entry specifies its own `Class<T>`, `List<T>` data, and pre-extracted `List<ExcelHeaderDto>` (use `extractExcelColumnDto` or build directly).
2. Pass the list to `drawMultipleSheetsFromDifferentDtos`; each `ExcelSheetDto` is turned into a sheet in iteration order.

---

## Usage Examples

### Single sheet — controller

```java
@RestController
@RequiredArgsConstructor
@RequestMapping("/adm/v1/users")
public class UserAdminController {

    private final UserService userService;
    private final ExcelSupportV1 excelSupportV1;   // injected by Spring

    @GetMapping("/excel")
    public void downloadUserExcel(
            @ModelAttribute UserSearchRequest request,
            HttpServletResponse response) {

        List<UserResponse> userList = userService.getUserListForExcel(request);
        List<UserExcelResponse> excelList = userList.stream()
                .map(UserExcelResponse::from)
                .collect(Collectors.toList());

        String fileName  = "공통프레임워크_사용자_목록_" + TimeUtils.formatDateTime(LocalDateTime.now());
        String sheetName = "사용자 목록";

        excelSupportV1.connect(response);
        excelSupportV1.drawSheet(sheetName, UserExcelResponse.class, excelList);
        excelSupportV1.downloadExcelFile(fileName);
    }
}
```

### Single sheet — response DTO

```java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class UserExcelResponse {

    @ExcelHeader(
            groupHeaderName  = "사용자 정보",
            groupHeaderOrder = 1,
            headerName       = "사용자 아이디",
            headerOrder      = 1
    )
    private String uerId;

    @ExcelHeader(
            groupHeaderName  = "사용자 정보",
            groupHeaderOrder = 1,
            headerName       = "사용자 이름",
            headerOrder      = 2
    )
    private String userNm;

    @ExcelHeader(
            groupHeaderName  = "사용자 정보",
            groupHeaderOrder = 1,
            headerName       = "등록일",
            headerOrder      = 3,
            columnWidth      = 30         // wider column for date strings
    )
    private String regDt;

    public static UserExcelResponse from(UserResponse src) {
        return new UserExcelResponse(
                src.getUserId(),
                src.getUserNm(),
                TimeUtils.formatDateTime(src.getRegDt(), "yyyy년 MM월 dd일 HH시 mm분")
        );
    }
}
```

### Multi-sheet from one DTO — controller

```java
@GetMapping("/{menuId}/boards/excel")
public void downloadBoardExcel(
        @PathVariable String menuId,
        @Valid @ModelAttribute BoardAdminSearchRequest searchDto,
        HttpServletResponse response) {

    List<BoardExcelResponse> excelList = boardService.getBoardListForExcel(menuId, searchDto);

    String fileName = menuId + "_게시물_목록_" + TimeUtils.formatDateTime(LocalDateTime.now());
    List<String> sheetNames = Arrays.asList("게시물 기본정보", "게시물 상세정보");

    excelSupportV1.connect(response);
    excelSupportV1.drawMultipleSheetsFromSingleDto(sheetNames, BoardExcelResponse.class, excelList);
    excelSupportV1.downloadExcelFile(fileName);
}
```

### Multi-sheet from one DTO — response DTO

```java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class BoardExcelResponse {

    // ---- Sheet 1 ----
    @ExcelHeader(sheetIndex = 1, groupHeaderName = "메뉴 제목 내용 헤더", groupHeaderOrder = 1,
                 headerName = "메뉴",  headerOrder = 1)
    private String menuId;

    @ExcelHeader(sheetIndex = 1, groupHeaderName = "메뉴 제목 내용 헤더", groupHeaderOrder = 1,
                 headerName = "제목", headerOrder = 2, columnWidth = 40)
    private String bbsTtl;

    @ExcelHeader(sheetIndex = 1, groupHeaderName = "조회수 헤더", groupHeaderOrder = 2,
                 headerName = "조회수", headerOrder = 1)
    private Long bbsInqCnt;

    // ---- Sheet 2 ----
    @ExcelHeader(sheetIndex = 2, groupHeaderName = "공개여부 삭제여부 헤더", groupHeaderOrder = 1,
                 headerName = "공개여부", headerOrder = 1)
    private String useYn;

    @ExcelHeader(sheetIndex = 2, groupHeaderName = "작성자 등록일시 헤더", groupHeaderOrder = 2,
                 headerName = "등록일시", headerOrder = 2, columnWidth = 20)
    private String regDt;
}
```

---

## Thread Safety Notes

- `ExcelUtilsV1` is a Spring singleton (`@Component`), but all mutable state (`SXSSFWorkbook`, `HttpServletResponse`) is stored in `ThreadLocal` — one instance per request thread.
- `workbookHolder` and `responseHolder` are always removed in the `finally` block of `downloadExcelFile()`. If `downloadExcelFile()` is never called (e.g., due to an exception before it is reached), the `ThreadLocal` entries will leak for that thread. Always ensure `downloadExcelFile()` is called, or wrap the three calls in a try-finally in the controller if an exception can occur between `connect()` and `downloadExcelFile()`.
- `Field.setAccessible(true)` is called per data row. This is safe for single-threaded per-request use but relies on the JVM not enforcing module access restrictions (Java 8 target, so no issue).
- `SXSSFWorkbook` itself is not thread-safe; never share a workbook instance across threads.
