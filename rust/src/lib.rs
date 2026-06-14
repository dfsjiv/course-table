use calamine::{Data, Reader, Xls};
use chrono::NaiveDate;
use regex::Regex;
use serde::Serialize;
use std::ffi::{c_char, CString};
use std::io::Cursor;
use std::slice;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct Timetable {
    semester: String,
    class_name: String,
    start_date: String,
    total_weeks: u32,
    courses: Vec<Course>,
}

#[derive(Debug, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
struct Course {
    name: String,
    weekday: u32,
    start_period: u32,
    end_period: u32,
    weeks: Vec<u32>,
    campus: String,
    room: String,
    teacher: String,
}

fn parse_weeks(text: &str) -> Vec<u32> {
    let part_re = Regex::new(r"(\d+)(?:-(\d+))?周(?:\((单|双)\))?").unwrap();
    let mut weeks = Vec::new();
    for captures in part_re.captures_iter(text) {
        let start: u32 = captures[1].parse().unwrap();
        let end: u32 = captures
            .get(2)
            .map(|value| value.as_str().parse().unwrap())
            .unwrap_or(start);
        let parity = captures.get(3).map(|value| value.as_str());
        weeks.extend((start..=end).filter(|week| match parity {
            Some("单") => week % 2 == 1,
            Some("双") => week % 2 == 0,
            _ => true,
        }));
    }
    weeks.sort_unstable();
    weeks.dedup();
    weeks
}

fn parse_course_cell(text: &str, weekday: u32, fallback_periods: (u32, u32), total_weeks: u32) -> Vec<Course> {
    let record_re = Regex::new(
        r"(?m)(?P<name>[^/\r\n]+)/\((?P<start>\d+)-(?P<end>\d+)节\)(?P<weeks>[^/]+)/(?P<place>[^/]+)/(?P<teacher>[^/]*)/",
    )
    .unwrap();
    let mut courses: Vec<Course> = record_re
        .captures_iter(text)
        .map(|record| {
            let place = record.name("place").unwrap().as_str().trim();
            let (campus, room) = place.split_once(' ').unwrap_or(("", place));
            Course {
                name: record.name("name").unwrap().as_str().trim().to_string(),
                weekday,
                start_period: record["start"].parse().unwrap(),
                end_period: record["end"].parse().unwrap(),
                weeks: parse_weeks(&record["weeks"]),
                campus: campus.to_string(),
                room: room.to_string(),
                teacher: record["teacher"].trim().to_string(),
            }
        })
        .collect();

    if courses.is_empty() && !text.trim().is_empty() {
        courses.push(Course {
            name: text.trim().to_string(),
            weekday,
            start_period: fallback_periods.0,
            end_period: fallback_periods.1,
            weeks: (1..=total_weeks).collect(),
            campus: String::new(),
            room: String::new(),
            teacher: String::new(),
        });
    }
    courses
}

fn cell_text(cell: Option<&Data>) -> String {
    cell.map(ToString::to_string).unwrap_or_default()
}

fn parse_xls(bytes: &[u8]) -> Result<Timetable, String> {
    let mut workbook = Xls::new(Cursor::new(bytes)).map_err(|error| error.to_string())?;
    let sheet_name = workbook
        .sheet_names()
        .first()
        .cloned()
        .ok_or("课表文件没有工作表")?;
    let range = workbook
        .worksheet_range(&sheet_name)
        .map_err(|error| error.to_string())?;

    let title = range.rows().next().map(|row| row.iter().map(ToString::to_string).collect::<Vec<_>>().join(" ")).unwrap_or_default();
    let note = range.rows().last().map(|row| row.iter().map(ToString::to_string).collect::<Vec<_>>().join(" ")).unwrap_or_default();
    let semester = Regex::new(r"(\d{4}-\d{4}年第\d学期)")
        .unwrap()
        .captures(&title)
        .map(|value| value[1].to_string())
        .unwrap_or_default();
    let class_name = Regex::new(r"([^\s]+课表)")
        .unwrap()
        .captures(&title)
        .map(|value| value[1].trim_end_matches("课表").to_string())
        .unwrap_or_default();
    let start_date = Regex::new(r"(\d{4}-\d{2}-\d{2})正式上课")
        .unwrap()
        .captures(&note)
        .and_then(|value| NaiveDate::parse_from_str(&value[1], "%Y-%m-%d").ok())
        .map(|value| value.format("%Y-%m-%d").to_string())
        .unwrap_or_default();
    let total_weeks = Regex::new(r"共(\d+)周")
        .unwrap()
        .captures(&note)
        .and_then(|value| value[1].parse().ok())
        .unwrap_or(20);

    let fallback_periods = [(1, 2), (3, 4), (5, 6), (7, 8), (9, 10), (11, 12)];
    let mut courses = Vec::new();
    for (row_index, periods) in fallback_periods.iter().enumerate() {
        let row = row_index + 2;
        for day in 0..7 {
            let text = cell_text(range.get((row, day + 2)));
            courses.extend(parse_course_cell(&text, (day + 1) as u32, *periods, total_weeks));
        }
    }
    if courses.is_empty() {
        return Err("未在文件中识别到课程".to_string());
    }
    Ok(Timetable { semester, class_name, start_date, total_weeks, courses })
}

fn json_result(result: Result<Timetable, String>) -> CString {
    let value = match result {
        Ok(timetable) => serde_json::json!({"ok": true, "timetable": timetable}),
        Err(message) => serde_json::json!({"ok": false, "error": message}),
    };
    CString::new(value.to_string()).unwrap()
}

#[no_mangle]
pub unsafe extern "C" fn parse_timetable_xls(data: *const u8, length: usize) -> *mut c_char {
    if data.is_null() || length == 0 {
        return json_result(Err("文件为空".to_string())).into_raw();
    }
    json_result(parse_xls(slice::from_raw_parts(data, length))).into_raw()
}

#[no_mangle]
pub unsafe extern "C" fn free_parser_string(value: *mut c_char) {
    if !value.is_null() {
        drop(CString::from_raw(value));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_mixed_week_ranges() {
        assert_eq!(parse_weeks("1-8周,10-14周(双)"), vec![1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14]);
        assert_eq!(parse_weeks("9-15周(单),16周"), vec![9, 11, 13, 15, 16]);
    }

    #[test]
    fn splits_room_and_course_fields() {
        let courses = parse_course_cell(
            "离散数学/(3-4节)9-15周(单)/校本部 实验实训楼北206(计算机综合实验室5)/刘宏芳/离散数学-0004/",
            5,
            (3, 4),
            20,
        );
        assert_eq!(courses[0].name, "离散数学");
        assert_eq!(courses[0].weeks, vec![9, 11, 13, 15]);
        assert_eq!(courses[0].room, "实验实训楼北206(计算机综合实验室5)");
    }

    #[test]
    fn keeps_incomplete_course_using_cell_position() {
        let courses = parse_course_cell("体育", 4, (5, 6), 20);
        assert_eq!(courses[0].start_period, 5);
        assert_eq!(courses[0].weeks.len(), 20);
    }
}
