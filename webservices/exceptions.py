
FORM_LINE_NUMBER_ERROR = """Invalid form_line_number detected. A valid form_line_number is using the following format: \
'FORM-LINENUMBER'.  For example an argument such as 'F3X-16' would filter down to all schedule a entries \
from form F3X line number 16.\
"""

LINE_NUMBER_ERROR = """Invalid line_number detected. A valid line_number is using the following format:
'FORM-LINENUMBER'.  For example an argument such as 'F3X-16' would filter down to all schedule a entries
from form F3X line number 16.\
"""

LINE_NUMBER_OBSOLETE_ERROR = """Obsolete, please use form_line_number.\
"""

IMAGE_NUMBER_ERROR = """Invalid image_number detected. A valid image_number is numeric only.\
"""

FILE_NUMBER_ERROR = """Invalid file_number detected. A valid file_number is numeric only.\
"""

KEYWORD_LENGTH_ERROR = """Invalid keyword. The keyword must be at least 3 characters in length.\
"""

NEXT_IN_CHAIN_DATA_ERROR = """next_in_chain data error, please contact apiinfo@fec.gov.\
"""

DATE_ERROR = """Invalid date. Date must be formatted as MM/DD/YYYY or YYYY-MM-DD.\
"""

FULLDATE_ERROR = """Invalid date. Date must be formatted as MM/DD/YYYY, YYYY-MM-DD,\
or ISO 8601 (YYYY-MM-DDTHH:MM:SS[+|-]HH:MM).\
"""

COMMITTEE_ID_ERROR = """Invalid committee_id. A valid committee_id begins with a 'C'\
 followed by 8 digits. For example: C00100005.\
"""

CANDIDATE_ID_ERROR = """Invalid candidate_id. A valid candidate_id begins with a 'P' or 'H' or 'S'\
 followed by 8 letters or numbers. For example: P00000034, S6MI00103, H0LA01087.\
"""

TWO_YEAR_TRANSACTION_PERIOD_ERROR = """Invalid two_year_transaction period. A\
 valid two_year_transaction_period should be an even year between 1976 and \
"""

TWO_YEAR_TRANSACTION_PERIOD_404 = """two_year_transaction_period not found.\
 Data exists for two_year_transaction_periods between 1976 and \
"""


class ApiError(Exception):
    status_code = 400

    def __init__(self, message, status_code=None, payload=None):
        super(ApiError, self).__init__()
        self.message = message
        self.status_code = status_code or self.status_code
        self.payload = payload

    def to_dict(self):
        ret = self.payload or {}
        ret['status'] = self.status_code
        ret['message'] = self.message
        return ret
