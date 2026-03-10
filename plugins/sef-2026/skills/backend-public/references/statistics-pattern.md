# Statistics Pattern Reference

## Overview

Statistics are embedded within their owning module rather than as separate modules.
Each statistics class queries pre-existing domain tables -- no separate statistics table.

| Statistics Class | Module | Description |
|-----------------|--------|-------------|
| `BbsStatistics` | `board/` | Board/post statistics (KPI counts, trends, category distribution) |
| `UserStatistics` | `user/` | User registration statistics (KPI counts, trends, role distribution) |
| `VisitStatistics` | `system/visitlog/` | Visit statistics (daily/monthly trends, device/browser distribution) |

---

## Domain Object Pattern

Statistics classes live in `modules/{module}/domain/` alongside the main domain class:

```
modules/board/
  domain/
    Board.java
    BbsStatistics.java    # ← statistics domain

modules/user/
  domain/
    User.java
    UserStatistics.java   # ← statistics domain

modules/system/visitlog/
  domain/
    VisitLog.java
    VisitStatistics.java  # ← statistics domain
```

---

## BbsStatistics Example

```java
// modules/board/domain/BbsStatistics.java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class BbsStatistics {

    // KPI
    private Long totalBbsCnt;       // Total board posts
    private Long todayBbsCnt;       # Today's posts
    private Long thisWeekBbsCnt;    # This week's posts
    private Long thisMonthBbsCnt;   # This month's posts

    // Trend (daily)
    private List<DailyCount> dailyTrend;    # Last 30 days

    // Distribution
    private List<CategoryCount> categoryDistribution;  # By menu/category

    @Getter
    @AllArgsConstructor
    public static class DailyCount {
        private String date;       # "YYYY-MM-DD"
        private Long count;
    }

    @Getter
    @AllArgsConstructor
    public static class CategoryCount {
        private String menuId;
        private String menuNm;
        private Long count;
    }
}
```

---

## Mapper Pattern

Statistics queries are added to the existing module mapper (NOT a separate mapper):

```java
// modules/board/mapper/BoardMapper.java
@Mapper("boardMapper")
public interface BoardMapper {
    // ... existing board CRUD methods ...

    BbsStatistics selectBbsStatistics();
}
```

```xml
<!-- mybatis/mapper/board/BoardMapper.xml -->
<select id="selectBbsStatistics" resultType="BbsStatistics">
    SELECT
        (SELECT COUNT(*) FROM bbs) AS total_bbs_cnt,
        (SELECT COUNT(*) FROM bbs WHERE DATE(reg_dtm) = CURRENT_DATE) AS today_bbs_cnt,
        (SELECT COUNT(*) FROM bbs WHERE reg_dtm >= DATE_TRUNC('week', CURRENT_DATE)) AS this_week_bbs_cnt,
        (SELECT COUNT(*) FROM bbs WHERE reg_dtm >= DATE_TRUNC('month', CURRENT_DATE)) AS this_month_bbs_cnt
</select>
```

**Note**: Trend and distribution data use separate `<select>` queries and are assembled in the service layer.

---

## Service Pattern

```java
// modules/board/service/impl/BoardServiceImpl.java
@Override
public BbsStatistics getBbsStatistics() {
    Long totalBbsCnt = boardMapper.selectTotalBbsCnt();
    Long todayBbsCnt = boardMapper.selectTodayBbsCnt();
    Long thisWeekBbsCnt = boardMapper.selectThisWeekBbsCnt();
    Long thisMonthBbsCnt = boardMapper.selectThisMonthBbsCnt();
    List<BbsStatistics.DailyCount> dailyTrend = boardMapper.selectDailyTrend();
    List<BbsStatistics.CategoryCount> categoryDistribution = boardMapper.selectCategoryDistribution();

    return new BbsStatistics(totalBbsCnt, todayBbsCnt, thisWeekBbsCnt, thisMonthBbsCnt,
                             dailyTrend, categoryDistribution);
}
```

---

## Controller Pattern

Statistics endpoints follow the same GET-only, admin-only pattern:

```java
// modules/board/controller/BoardAdminController.java
@Tag(name = "Board Admin", description = "Board Admin API")
@RestController
@RequestMapping("/adm/v1/boards")
@RequiredArgsConstructor
public class BoardAdminController {

    private final BoardService boardService;

    @Operation(summary = "Board statistics")
    @GetMapping("/statistics")
    public ResponseEntity<ApiResponse<BbsStatistics>> getBbsStatistics() {
        BbsStatistics statistics = boardService.getBbsStatistics();
        return ResponseEntity.ok(ApiResponse.success(statistics));
    }
}
```

---

## UserStatistics Example

```java
// modules/user/domain/UserStatistics.java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class UserStatistics {

    private Long totalUserCnt;
    private Long todayJoinCnt;
    private Long thisMonthJoinCnt;
    private Long activeUserCnt;        # Last 30 days login
    private Long dormantUserCnt;       # No login > 1 year

    private List<DailyCount> joinTrend;          # Daily registrations (last 30 days)
    private List<RoleCount> roleDistribution;    # By role

    @Getter
    @AllArgsConstructor
    public static class DailyCount {
        private String date;
        private Long count;
    }

    @Getter
    @AllArgsConstructor
    public static class RoleCount {
        private String roleId;
        private String roleNm;
        private Long count;
    }
}
```

---

## VisitStatistics Example

```java
// modules/system/visitlog/domain/VisitStatistics.java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class VisitStatistics {

    private Long todayVisitCnt;
    private Long thisWeekVisitCnt;
    private Long thisMonthVisitCnt;
    private Long totalVisitCnt;

    private List<DailyCount> dailyTrend;            # Last 30 days
    private List<DeviceCount> deviceDistribution;   # Mobile / Desktop / Tablet
    private List<BrowserCount> browserDistribution; # Chrome / Safari / etc.

    @Getter
    @AllArgsConstructor
    public static class DailyCount {
        private String date;
        private Long count;
    }

    @Getter
    @AllArgsConstructor
    public static class DeviceCount {
        private String deviceType;
        private Long count;
    }

    @Getter
    @AllArgsConstructor
    public static class BrowserCount {
        private String browser;
        private Long count;
    }
}
```

---

## Checklist

- [ ] Statistics class lives in `modules/{module}/domain/` (NOT a separate module)
- [ ] Statistics queries added to existing module Mapper (NOT a new mapper)
- [ ] KPI fields: total, today, this week, this month counts
- [ ] Trend data: daily counts for last 30 days (date string + count)
- [ ] Distribution data: breakdown by category/role/device (name + count)
- [ ] Statistics endpoint: `GET /adm/v1/{resources}/statistics` (admin only, no `@PreAuthorize` menu check needed)
- [ ] Assembly of statistics done in ServiceImpl (multiple mapper calls → one domain object)
