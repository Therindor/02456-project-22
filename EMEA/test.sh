#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

OUTPUT_DIR="${1:-wmt16_de_en}"
echo "Writing to ${OUTPUT_DIR}. To change this, set the OUTPUT_DIR environment variable."


# Tokenize data
for f in ${OUTPUT_DIR}/*.de; do
  echo "Tokenizing $f..."
  ${OUTPUT_DIR}/mosesdecoder/scripts/tokenizer/tokenizer.perl -q -l de -threads 8 < $f > ${f%.*}.tok.de
done

for f in ${OUTPUT_DIR}/*.en; do
  echo "Tokenizing $f..."
  ${OUTPUT_DIR}/mosesdecoder/scripts/tokenizer/tokenizer.perl -q -l en -threads 8 < $f > ${f%.*}.tok.en
done

# Clean all corpora
for f in ${OUTPUT_DIR}/*.en; do
  fbase=${f%.*}
  echo "Cleaning ${fbase}..."
  ${OUTPUT_DIR}/mosesdecoder/scripts/training/clean-corpus-n.perl $fbase de en "${fbase}.clean" 1 80
done

# Learn Shared BPE
for merge_ops in 32000; do
  echo "Learning BPE with merge_ops=${merge_ops}. This may take a while..."
  cat "${OUTPUT_DIR}/train.tok.clean.de" "${OUTPUT_DIR}/train.tok.clean.en" | \
    ${OUTPUT_DIR}/subword-nmt/learn_bpe.py -s $merge_ops > "${OUTPUT_DIR}/bpe.${merge_ops}"

  echo "Apply BPE with merge_ops=${merge_ops} to tokenized files..."
  for lang in en de; do
    for f in ${OUTPUT_DIR}/*.tok.${lang} ${OUTPUT_DIR}/*.tok.clean.${lang}; do
      outfile="${f%.*}.bpe.${merge_ops}.${lang}"
      ${OUTPUT_DIR}/subword-nmt/apply_bpe.py -c "${OUTPUT_DIR}/bpe.${merge_ops}" < $f > "${outfile}"
      echo ${outfile}
    done
  done

  # Create vocabulary file for BPE
  echo -e "<unk>\n<s>\n</s>" > "${OUTPUT_DIR}/vocab.bpe.${merge_ops}"
  cat "${OUTPUT_DIR}/train.tok.clean.bpe.${merge_ops}.en" "${OUTPUT_DIR}/train.tok.clean.bpe.${merge_ops}.de" | \
    ${OUTPUT_DIR}/subword-nmt/get_vocab.py | cut -f1 -d ' ' >> "${OUTPUT_DIR}/vocab.bpe.${merge_ops}"

done

# Duplicate vocab file with language suffix
cp "${OUTPUT_DIR}/vocab.bpe.32000" "${OUTPUT_DIR}/vocab.bpe.32000.en"
cp "${OUTPUT_DIR}/vocab.bpe.32000" "${OUTPUT_DIR}/vocab.bpe.32000.de"

echo "All done."

