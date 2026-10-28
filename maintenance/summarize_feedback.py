"""Turn owner-exported D1 rows into a review queue, never into automatic facts."""
import argparse
import collections
import json
from pathlib import Path

def summarize(rows):
    unique={}
    for row in rows:
        raw=row.get('report_json', row)
        report=json.loads(raw) if isinstance(raw,str) else raw
        if report.get('version','').endswith('-qa') or 'QA' in report.get('comment',''):
            continue
        unique.setdefault(report['id'],report)
    books=collections.Counter(); questions=collections.Counter(); outcomes=collections.Counter()
    versions=collections.Counter(); unknown=collections.Counter(); asked=collections.Counter()
    for r in unique.values():
        outcomes[r['outcome']]+=1; versions[r['version']]+=1
        if r['outcome']!='confirmed':
            books[(r.get('bookId',''),r.get('bookTitle',''),r.get('character',''))]+=1
        questions.update(set(r.get('unclear',[])))
        for e in r.get('events',[]):
            if e.get('type')=='answer':
                asked[e['question']]+=1
                if e.get('value')==0: unknown[e['question']]+=1
    return {'visitor_reports':len(unique),'outcomes':dict(outcomes),'versions':dict(versions),
        'review_queue':[{'book_id':key[0],'title':key[1],'character':key[2],'reports':n,'status':'needs_source_review'} for key,n in books.most_common()],
        'unclear_questions':[{'id':q,'reports':n} for q,n in questions.most_common()],
        'unknown_answers':[{'id':q,'unknown':n,'answers':asked[q]} for q,n in unknown.most_common()],
        'note':'Counts are submitted reports, not unique people. No automatic fact updates. QA excluded.'}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('input',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
    data=json.loads(a.input.read_text(encoding='utf-8'))
    rows=data if isinstance(data,list) else data.get('rows',data.get('structuredContent',{}).get('rows',[]))
    a.output.write_text(json.dumps(summarize(rows),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
