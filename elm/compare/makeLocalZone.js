/**
 * Extracts local time zone info used by `Date` for a given range of years.
 *
 * @param  {Number} `startYear`
 * @param  {Number} `endYear`
 *
 * @return {object} `initial` key holds the zone's starting offset,
 *                  `changes` key holds the list of offset changes
 */

const makeLocalZone = (startYear, endYear) => {
  const MILLIS_IN_MINUTE = 60000;
  const MILLIS_IN_HOUR = 3600000;
  const MILLIS_IN_DAY = 86400000;

  const startDate = new Date(startYear, 0, 1);
  const endDate = new Date(endYear, 11, 31);

  const getChanges = (startDate, endDate) => {
    const endTime = endDate.getTime();
    const changes = [];

    var time = startDate.getTime();
    var prevOffset = -startDate.getTimezoneOffset();
    var offset;

    while (time < endTime) {
      offset = -(new Date(time).getTimezoneOffset());

      if (offset !== prevOffset) {
        changes.unshift(findOffsetChange(time - MILLIS_IN_DAY, offset));
        prevOffset = offset;
      }

      time = time + MILLIS_IN_DAY;
    }

    return changes;
  };

  const findOffsetChange = (time, targetOffset) => {
    const offset = -(new Date(time).getTimezoneOffset());

    return offset === targetOffset
      ? { start: time / MILLIS_IN_MINUTE, offset: offset }
      : findOffsetChange(time + MILLIS_IN_HOUR, targetOffset);
  };

  return {
    initial: -startDate.getTimezoneOffset(),
    changes: getChanges(startDate, endDate)
  };
};
